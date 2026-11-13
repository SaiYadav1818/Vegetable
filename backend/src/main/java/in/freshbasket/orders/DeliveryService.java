package in.freshbasket.orders;

import in.freshbasket.notifications.BusinessNotificationPublisher;
import in.freshbasket.user.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class DeliveryService {
    private final UserRepository users; private final DriverProfileRepository drivers; private final DriverAssignmentRepository assignments;
    private final DriverLocationRepository locations; private final DeliveryOtpRepository otps; private final OrderItemRepository orderItems;
    private final PaymentRepository payments; private final PasswordEncoder encoder; private final OrderService orders;
    private final BusinessNotificationPublisher notificationPublisher;

    public DeliveryService(UserRepository users,DriverProfileRepository drivers,DriverAssignmentRepository assignments,DriverLocationRepository locations,
            DeliveryOtpRepository otps,OrderItemRepository orderItems,PaymentRepository payments,PasswordEncoder encoder,OrderService orders,
            BusinessNotificationPublisher notificationPublisher){
        this.users=users;this.drivers=drivers;this.assignments=assignments;this.locations=locations;this.otps=otps;this.orderItems=orderItems;this.payments=payments;this.encoder=encoder;this.orders=orders;
        this.notificationPublisher=notificationPublisher;
    }

    @Transactional public OrderDtos.DriverResponse createDriver(String email,OrderDtos.DriverCreateRequest request){
        orders.requireAdmin(email);String normalized=request.email().trim().toLowerCase();
        if(users.existsByEmail(normalized))throw new ResponseStatusException(HttpStatus.CONFLICT,"Email is already registered");
        if(users.existsByPhoneNumber(request.phoneNumber()))throw new ResponseStatusException(HttpStatus.CONFLICT,"Phone number is already registered");
        AppUser user=users.save(new AppUser(normalized,encoder.encode(request.password()),request.fullName().trim(),request.phoneNumber().trim(),Role.DRIVER));
        DriverProfile profile=drivers.save(new DriverProfile(user));return driverDto(profile);
    }
    @Transactional(readOnly=true) public Page<OrderDtos.DriverResponse> drivers(Pageable pageable){return drivers.findAll(pageable).map(this::driverDto);}
    @Transactional public void availability(String email,boolean online){AppUser user=driver(email);DriverProfile profile=drivers.findLocked(user.getId()).orElseThrow(()->notFound("Driver profile not found"));
        boolean active= !assignments.findByDriver_User_IdAndStatusIn(user.getId(),List.of(AssignmentStatus.ASSIGNED,AssignmentStatus.ACCEPTED,AssignmentStatus.PICKED_UP)).isEmpty();
        if(active&&!online)throw conflict("Complete your active delivery before going offline");profile.setOnline(online);profile.setAvailable(online&&!active);
    }
    @Transactional public OrderDtos.OrderResponse assign(long orderId,long driverId,String email){
        AppUser admin=orders.requireAdmin(email);CustomerOrder order=orders.lockOrder(orderId);
        if(order.getStatus()!=OrderStatus.READY_FOR_PICKUP && order.getStatus()!=OrderStatus.DELIVERY_FAILED){
            throw conflict("Order must be ready for pickup or in failed delivery state before driver assignment");
        }
        Optional<DriverAssignment> activeAssignment = assignments.findFirstByOrder_IdAndStatusIn(orderId,
                List.of(AssignmentStatus.ASSIGNED, AssignmentStatus.ACCEPTED, AssignmentStatus.PICKED_UP));
        if (activeAssignment.isPresent()) {
            DriverAssignment old = activeAssignment.get();
            if (old.getDriver().getUser().getId().equals(driverId)) {
                throw conflict("Order is already actively assigned to this driver");
            }
            old.cancel("Reassigned by admin to another driver");
            DriverProfile oldProfile = old.getDriver();
            oldProfile.setAvailable(oldProfile.isOnline());
        }
        DriverProfile profile=drivers.findLocked(driverId).orElseThrow(()->notFound("Driver not found"));
        if(!profile.getUser().isActive()||!profile.isOnline()||!profile.isAvailable())throw conflict("Driver is offline or already assigned");
        assignments.save(new DriverAssignment(order,profile,admin));profile.setAvailable(false);
        orders.changeStatus(order,OrderStatus.DRIVER_ASSIGNED,admin,"Assigned to "+profile.getUser().getFullName());
        notificationPublisher.driverAssigned(order,profile.getUser());
        return orders.response(order,null);
    }
    @Transactional(readOnly=true) public Page<OrderDtos.DriverOrderResponse> assigned(String email,Pageable pageable){AppUser user=driver(email);return assignments.findByDriver_User_Id(user.getId(),pageable).map(this::driverOrderDto);}
    @Transactional(readOnly=true) public OrderDtos.OrderResponse assignedOrder(long orderId,String email){AppUser user=driver(email);ownedAssignment(orderId,user.getId());CustomerOrder order=orders.getForAuthorizedDriver(orderId);return orders.response(order,null);}
    @Transactional public OrderDtos.DriverOrderResponse accept(long orderId,String email){
        AppUser user=driver(email);DriverAssignment a=ownedAssignment(orderId,user.getId());
        if(a.getStatus()!=AssignmentStatus.ASSIGNED)throw conflict("This delivery is no longer awaiting acceptance");
        a.accept();return driverOrderDto(a);
    }
    @Transactional public OrderDtos.DriverOrderResponse pickup(long orderId,String email){
        AppUser user=driver(email);DriverAssignment a=ownedAssignment(orderId,user.getId());
        if(a.getStatus()!=AssignmentStatus.ACCEPTED)throw conflict("Accept the delivery before pickup");
        a.pickup();CustomerOrder order=orders.lockOrder(orderId);orders.changeStatus(order,OrderStatus.OUT_FOR_DELIVERY,user,"Driver picked up the order");
        return driverOrderDto(a);
    }
    @Transactional public OrderDtos.DriverOrderResponse fail(long orderId,String email,OrderDtos.DeliveryFailRequest request){
        AppUser user=driver(email);DriverAssignment a=ownedAssignment(orderId,user.getId());
        if(a.getStatus()!=AssignmentStatus.ACCEPTED && a.getStatus()!=AssignmentStatus.PICKED_UP){
            throw conflict("Delivery can only be reported failed after acceptance or pickup");
        }
        CustomerOrder order=orders.lockOrder(orderId);
        String reason=request.reason().trim();
        a.fail(reason);
        DriverProfile profile=a.getDriver();
        profile.setAvailable(profile.isOnline());
        locations.findById(user.getId()).ifPresent(DriverLocation::stop);
        orders.changeStatus(order,OrderStatus.DELIVERY_FAILED,user,reason);
        return driverOrderDto(a);
    }
    @Transactional(noRollbackFor=InvalidDeliveryOtpException.class) public OrderDtos.OrderResponse deliver(long orderId,String email,OrderDtos.DeliverRequest request){
        AppUser user=driver(email);DriverAssignment a=ownedAssignment(orderId,user.getId());
        if(a.getStatus()!=AssignmentStatus.PICKED_UP)throw conflict("Order must be picked up before delivery");
        CustomerOrder order=orders.lockOrder(orderId);DeliveryOtp otp=otps.findLocked(orderId).orElseThrow(()->notFound("Delivery code not found"));
        if(otp.getFailedAttempts()>=5)throw new ResponseStatusException(HttpStatus.LOCKED,"Too many incorrect delivery codes");
        if(otp.isExpired())throw new ResponseStatusException(HttpStatus.GONE,"Delivery code expired; ask the customer to generate a new one");
        if(!otp.matches(request.otp(),encoder)){otp.failed();throw new InvalidDeliveryOtpException();}
        otp.verify();a.deliver();DriverProfile profile=a.getDriver();profile.setAvailable(profile.isOnline());
        locations.findById(user.getId()).ifPresent(DriverLocation::stop);
        orders.changeStatus(order,OrderStatus.DELIVERED,user,"Delivery verified by customer OTP");
        Payment payment=payments.findByOrder_Id(orderId).orElse(null);
        if(request.cashCollected()){
            order.paymentStatus(PaymentStatus.PAID);
            if(payment!=null) payment.markCollected(user,Instant.now());
        }else{
            order.paymentStatus(PaymentStatus.PENDING);
            if(payment!=null) payment.markUnpaid();
        }
        return orders.response(order,null);
    }
    @Transactional public void location(String email,OrderDtos.DriverLocationRequest request){
        AppUser user=driver(email);List<DriverAssignment> active=assignments.findByDriver_User_IdAndStatusIn(user.getId(),List.of(AssignmentStatus.ACCEPTED,AssignmentStatus.PICKED_UP));
        if(active.isEmpty())throw conflict("Location sharing is only available during an active delivery");
        DriverAssignment assignment=active.get(0);DriverProfile profile=assignment.getDriver();
        DriverLocation location=locations.findById(user.getId()).orElse(null);
        if(location==null)locations.save(new DriverLocation(profile,assignment,request.latitude(),request.longitude()));
        else location.update(assignment,request.latitude(),request.longitude());
    }

    // COD Payment Reconciliation
    @Transactional(readOnly=true) public OrderDtos.CodReconciliationReport codReconciliationReport(String email){
        orders.requireAdmin(email);
        List<Payment> allPayments = payments.findAll();
        BigDecimal totalCollected = BigDecimal.ZERO;
        BigDecimal totalSettled = BigDecimal.ZERO;
        BigDecimal totalUnsettled = BigDecimal.ZERO;
        long unpaidDelivered = payments.countUnpaidDelivered();

        Map<Long, DriverAccumulator> driverMap = new HashMap<>();
        List<OrderDtos.PaymentReconciliationItem> unsettledItems = new ArrayList<>();

        for(Payment p : allPayments){
            if(p.getStatus() == PaymentStatus.PAID){
                totalCollected = totalCollected.add(p.getAmount());
                if(p.isReconciled()){
                    totalSettled = totalSettled.add(p.getAmount());
                } else {
                    totalUnsettled = totalUnsettled.add(p.getAmount());
                    unsettledItems.add(paymentReconciliationItem(p));
                }
                if(p.getCollectedBy() != null){
                    AppUser d = p.getCollectedBy();
                    DriverAccumulator acc = driverMap.computeIfAbsent(d.getId(), id -> new DriverAccumulator(d.getId(), d.getFullName(), d.getPhoneNumber()));
                    if(p.isReconciled()){
                        acc.settledCount++;
                        acc.settledAmount = acc.settledAmount.add(p.getAmount());
                    } else {
                        acc.unsettledCount++;
                        acc.unsettledAmount = acc.unsettledAmount.add(p.getAmount());
                    }
                }
            }
        }
        List<OrderDtos.DriverReconciliationSummary> driverSummaries = driverMap.values().stream()
                .map(a -> new OrderDtos.DriverReconciliationSummary(a.id, a.name, a.phone, a.unsettledCount, a.unsettledAmount, a.settledCount, a.settledAmount))
                .toList();

        return new OrderDtos.CodReconciliationReport(totalCollected, totalSettled, totalUnsettled, unpaidDelivered, driverSummaries, unsettledItems);
    }

    @Transactional public OrderDtos.PaymentReconciliationItem reconcilePayment(long paymentId,OrderDtos.ReconcilePaymentRequest request,String email){
        AppUser admin=orders.requireAdmin(email);
        Payment payment=payments.findById(paymentId).orElseThrow(()->notFound("Payment record not found"));
        if(payment.getStatus()!=PaymentStatus.PAID)throw conflict("Payment must be marked collected (PAID) before reconciliation");
        payment.reconcile(admin, clean(request==null?null:request.note()));
        return paymentReconciliationItem(payment);
    }

    @Transactional public int reconcileDriverPayments(long driverId,OrderDtos.ReconcilePaymentRequest request,String email){
        AppUser admin=orders.requireAdmin(email);
        List<Payment> list=payments.findByCollectedBy_IdAndReconciledFalse(driverId);
        String note=clean(request==null?null:request.note());
        int count=0;
        for(Payment p:list){
            if(p.getStatus()==PaymentStatus.PAID){
                p.reconcile(admin, note);
                count++;
            }
        }
        return count;
    }

    private DriverAssignment ownedAssignment(long orderId,long driverId){
        DriverAssignment a=assignments.findLockedByOrderIdAndStatusIn(orderId,List.of(AssignmentStatus.ASSIGNED,AssignmentStatus.ACCEPTED,AssignmentStatus.PICKED_UP))
                .orElseThrow(()->notFound("Active delivery assignment not found"));
        if(!a.getDriver().getUser().getId().equals(driverId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"This delivery is assigned to another driver");
        return a;
    }
    private OrderDtos.DriverOrderResponse driverOrderDto(DriverAssignment a){CustomerOrder o=a.getOrder();var lines=orderItems.findByOrder_IdOrderById(o.getId()).stream().map(i->new OrderDtos.OrderItemResponse(i.getProductName(),i.getUnit().name(),i.getQuantity(),i.getUnitPrice(),i.getLineTotal())).toList();
        return new OrderDtos.DriverOrderResponse(a.getId(),o.getId(),o.getOrderNumber(),a.getStatus(),o.getStatus(),o.getCustomer().getFullName(),o.getRecipientPhone(),o.getAddressLine(),o.getHouseNumber(),o.getArea(),o.getLandmark(),o.getPincode(),o.getDeliveryInstructions(),o.getTotalAmount(),o.getDeliveryDate(),o.getDeliverySlot(),lines);
    }
    private OrderDtos.PaymentReconciliationItem paymentReconciliationItem(Payment p){
        AppUser d = p.getCollectedBy();
        return new OrderDtos.PaymentReconciliationItem(p.getId(), p.getOrder().getId(), p.getOrder().getOrderNumber(), p.getAmount(), p.getStatus(),
                d == null ? null : d.getId(), d == null ? null : d.getFullName(), d == null ? null : d.getPhoneNumber(),
                p.getCollectedAt(), p.isReconciled(), p.getReconciledAt(), p.getReconciliationNote());
    }
    private OrderDtos.DriverResponse driverDto(DriverProfile d){return new OrderDtos.DriverResponse(d.getUser().getId(),d.getUser().getFullName(),d.getUser().getEmail(),d.getUser().getPhoneNumber(),d.isOnline(),d.isAvailable());}
    private AppUser driver(String email){return users.findByEmail(email).filter(u->u.getRole()==Role.DRIVER&&u.isActive()).orElseThrow(()->new ResponseStatusException(HttpStatus.FORBIDDEN,"Driver account required"));}
    private ResponseStatusException notFound(String s){return new ResponseStatusException(HttpStatus.NOT_FOUND,s);}private ResponseStatusException conflict(String s){return new ResponseStatusException(HttpStatus.CONFLICT,s);}
    private String clean(String s){return s==null||s.isBlank()?null:s.trim();}
    static class InvalidDeliveryOtpException extends ResponseStatusException {InvalidDeliveryOtpException(){super(HttpStatus.UNAUTHORIZED,"Incorrect delivery code");}}
    private static class DriverAccumulator {
        final Long id; final String name; final String phone;
        long unsettledCount = 0; BigDecimal unsettledAmount = BigDecimal.ZERO;
        long settledCount = 0; BigDecimal settledAmount = BigDecimal.ZERO;
        DriverAccumulator(Long id, String name, String phone){this.id=id;this.name=name;this.phone=phone;}
    }
}
