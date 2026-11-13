package in.freshbasket.orders;

import in.freshbasket.user.*;
import in.freshbasket.notifications.BusinessNotificationPublisher;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
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
    private final PaymentRepository payments; private final PasswordEncoder encoder; private final OrderService orders; private final BusinessNotificationPublisher notificationPublisher;
    public DeliveryService(UserRepository users,DriverProfileRepository drivers,DriverAssignmentRepository assignments,DriverLocationRepository locations,
            DeliveryOtpRepository otps,OrderItemRepository orderItems,PaymentRepository payments,PasswordEncoder encoder,OrderService orders,BusinessNotificationPublisher notificationPublisher){
        this.users=users;this.drivers=drivers;this.assignments=assignments;this.locations=locations;this.otps=otps;this.orderItems=orderItems;this.payments=payments;this.encoder=encoder;this.orders=orders;this.notificationPublisher=notificationPublisher;
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
        if(order.getStatus()!=OrderStatus.READY_FOR_PICKUP)throw conflict("Order must be ready for pickup before driver assignment");
        if(assignments.findByOrder_Id(orderId).isPresent())throw conflict("Order already has a driver assignment");
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
    @Transactional(noRollbackFor=InvalidDeliveryOtpException.class) public OrderDtos.OrderResponse deliver(long orderId,String email,OrderDtos.DeliverRequest request){
        AppUser user=driver(email);DriverAssignment a=ownedAssignment(orderId,user.getId());
        if(a.getStatus()!=AssignmentStatus.PICKED_UP)throw conflict("Order must be picked up before delivery");
        CustomerOrder order=orders.lockOrder(orderId);DeliveryOtp otp=otps.findLocked(orderId).orElseThrow(()->notFound("Delivery code not found"));
        if(otp.getFailedAttempts()>=5)throw new ResponseStatusException(HttpStatus.LOCKED,"Too many incorrect delivery codes");
        if(otp.isExpired())throw new ResponseStatusException(HttpStatus.GONE,"Delivery code expired; ask the customer to generate a new one");
        if(!otp.matches(request.otp(),encoder)){otp.failed();throw new InvalidDeliveryOtpException();}
        otp.verify();a.deliver();DriverProfile profile=a.getDriver();profile.setAvailable(profile.isOnline());
        locations.findById(user.getId()).ifPresent(DriverLocation::stop);
        orders.changeStatus(order,OrderStatus.DELIVERED,user,"Delivery verified by customer OTP");order.paymentStatus(PaymentStatus.PAID);
        payments.findByOrder_Id(orderId).ifPresent(Payment::markPaid);
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
    private DriverAssignment ownedAssignment(long orderId,long driverId){
        DriverAssignment a=assignments.findLockedByOrderId(orderId).orElseThrow(()->notFound("Delivery assignment not found"));
        if(!a.getDriver().getUser().getId().equals(driverId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"This delivery is assigned to another driver");return a;
    }
    private OrderDtos.DriverOrderResponse driverOrderDto(DriverAssignment a){CustomerOrder o=a.getOrder();var lines=orderItems.findByOrder_IdOrderById(o.getId()).stream().map(i->new OrderDtos.OrderItemResponse(i.getProductName(),i.getUnit().name(),i.getQuantity(),i.getUnitPrice(),i.getLineTotal())).toList();
        return new OrderDtos.DriverOrderResponse(a.getId(),o.getId(),o.getOrderNumber(),a.getStatus(),o.getStatus(),o.getCustomer().getFullName(),o.getRecipientPhone(),o.getAddressLine(),o.getHouseNumber(),o.getArea(),o.getLandmark(),o.getPincode(),o.getDeliveryInstructions(),o.getTotalAmount(),o.getDeliveryDate(),o.getDeliverySlot(),lines);
    }
    private OrderDtos.DriverResponse driverDto(DriverProfile d){return new OrderDtos.DriverResponse(d.getUser().getId(),d.getUser().getFullName(),d.getUser().getEmail(),d.getUser().getPhoneNumber(),d.isOnline(),d.isAvailable());}
    private AppUser driver(String email){return users.findByEmail(email).filter(u->u.getRole()==Role.DRIVER&&u.isActive()).orElseThrow(()->new ResponseStatusException(HttpStatus.FORBIDDEN,"Driver account required"));}
    private ResponseStatusException notFound(String s){return new ResponseStatusException(HttpStatus.NOT_FOUND,s);}private ResponseStatusException conflict(String s){return new ResponseStatusException(HttpStatus.CONFLICT,s);}
    static class InvalidDeliveryOtpException extends ResponseStatusException {InvalidDeliveryOtpException(){super(HttpStatus.UNAUTHORIZED,"Incorrect delivery code");}}
}
