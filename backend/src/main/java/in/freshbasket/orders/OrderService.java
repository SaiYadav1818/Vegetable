package in.freshbasket.orders;

import in.freshbasket.catalog.*;
import in.freshbasket.notifications.BusinessNotificationPublisher;
import in.freshbasket.user.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class OrderService {
    private static final SecureRandom RANDOM=new SecureRandom();
    private final UserRepository users; private final CartRepository carts; private final CartItemRepository cartItems;
    private final OrderRepository orders; private final OrderItemRepository orderItems; private final OrderHistoryRepository history;
    private final PaymentRepository payments; private final DeliveryOtpRepository otps; private final DriverAssignmentRepository assignments;
    private final DriverLocationRepository locations; private final ProductRepository products; private final InventoryRepository inventory;
    private final InventoryTransactionRepository inventoryTransactions;
    private final BusinessNotificationPublisher notificationPublisher;
    private final PasswordEncoder passwordEncoder;
    private final BigDecimal minimumOrder; private final BigDecimal deliveryCharge;
    private in.freshbasket.shop.ShopSettingsService shopSettingsService;
    public OrderService(UserRepository users,CartRepository carts,CartItemRepository cartItems,OrderRepository orders,OrderItemRepository orderItems,
            OrderHistoryRepository history,PaymentRepository payments,DeliveryOtpRepository otps,DriverAssignmentRepository assignments,
            DriverLocationRepository locations,ProductRepository products,InventoryRepository inventory,InventoryTransactionRepository inventoryTransactions,
            BusinessNotificationPublisher notificationPublisher,
            PasswordEncoder passwordEncoder,@Value("${app.order.minimum-value:0.00}") BigDecimal minimumOrder,
            @Value("${app.order.delivery-charge:0.00}") BigDecimal deliveryCharge,
            @org.springframework.beans.factory.annotation.Autowired(required=false) in.freshbasket.shop.ShopSettingsService shopSettingsService){
        this.users=users;this.carts=carts;this.cartItems=cartItems;this.orders=orders;this.orderItems=orderItems;this.history=history;this.payments=payments;
        this.otps=otps;this.assignments=assignments;this.locations=locations;this.products=products;this.inventory=inventory;this.inventoryTransactions=inventoryTransactions;
        this.notificationPublisher=notificationPublisher;
        this.passwordEncoder=passwordEncoder;this.minimumOrder=minimumOrder;this.deliveryCharge=deliveryCharge;
        this.shopSettingsService=shopSettingsService;
    }

    public OrderService(UserRepository users,CartRepository carts,CartItemRepository cartItems,OrderRepository orders,OrderItemRepository orderItems,
            OrderHistoryRepository history,PaymentRepository payments,DeliveryOtpRepository otps,DriverAssignmentRepository assignments,
            DriverLocationRepository locations,ProductRepository products,InventoryRepository inventory,InventoryTransactionRepository inventoryTransactions,
            BusinessNotificationPublisher notificationPublisher,
            PasswordEncoder passwordEncoder,BigDecimal minimumOrder,BigDecimal deliveryCharge){
        this(users,carts,cartItems,orders,orderItems,history,payments,otps,assignments,locations,products,inventory,inventoryTransactions,notificationPublisher,passwordEncoder,minimumOrder,deliveryCharge,null);
    }

    @Transactional public OrderDtos.OrderResponse place(String email,OrderDtos.CheckoutRequest request){
        AppUser customer=customer(email);
        String idempotencyKey=clean(request.idempotencyKey());
        if(idempotencyKey!=null){
            Optional<CustomerOrder> existing=orders.findByCustomer_IdAndIdempotencyKey(customer.getId(),idempotencyKey);
            if(existing.isPresent()){
                return response(existing.get(),null);
            }
        }
        Cart cart=carts.findByCustomer_Id(customer.getId()).orElseThrow(()->badRequest("Your cart is empty"));
        List<CartItem> lines=cartItems.findByCart_IdOrderByProduct_Id(cart.getId());if(lines.isEmpty())throw badRequest("Your cart is empty");
        List<LockedLine> checked=new ArrayList<>();BigDecimal subtotal=BigDecimal.ZERO;
        for(CartItem line:lines){
            Product p=products.findById(line.getProduct().getId()).orElseThrow(()->conflict("A cart item is no longer available"));
            if(!sellable(p))throw conflict(p.getName()+" is no longer available");
            Inventory stock=inventory.findLockedByProductId(p.getId()).orElseThrow(()->conflict("Stock record is missing for "+p.getName()));
            if(stock.getSellableQuantity().compareTo(line.getQuantity())<0)throw conflict("Stock changed for "+p.getName()+". Update your cart before checkout.");
            BigDecimal lineTotal=money(p.getPrice().multiply(line.getQuantity()));subtotal=subtotal.add(lineTotal);checked.add(new LockedLine(line,p,stock,lineTotal));
        }
        subtotal=money(subtotal);
        if(subtotal.compareTo(request.expectedSubtotal())!=0)throw conflict("Prices changed. Review the updated cart total before confirming.");
        in.freshbasket.shop.ShopSettings settings = shopSettingsService != null ? shopSettingsService.getOrCreateSettings() : null;
        if(settings != null && !settings.isOpenToday()) throw badRequest("Shop is temporarily closed today" + (settings.getAnnouncementBanner() != null ? ": " + settings.getAnnouncementBanner() : ""));
        BigDecimal minOrder = settings != null ? settings.getMinOrderValue() : minimumOrder;
        if(subtotal.compareTo(minOrder)<0)throw badRequest("Minimum order value is Rs. "+minOrder.setScale(2,RoundingMode.HALF_UP));
        BigDecimal finalDeliveryCharge = settings != null ? shopSettingsService.calculateDeliveryCharge(subtotal) : deliveryCharge;
        BigDecimal total=money(subtotal.add(finalDeliveryCharge));
        CustomerOrder order=new CustomerOrder("FB-"+UUID.randomUUID().toString().replace("-","").substring(0,12).toUpperCase(Locale.ROOT),customer,
                subtotal,finalDeliveryCharge,total,request.recipientName().trim(),request.recipientPhone().trim(),request.addressLine().trim(),clean(request.houseNumber()),
                request.area().trim(),clean(request.landmark()),request.pincode(),clean(request.deliveryInstructions()),request.deliveryDate(),request.deliverySlot(),request.latitude(),request.longitude());
        order.setIdempotencyKey(idempotencyKey);
        order=orders.save(order);
        for(LockedLine line:checked){
            BigDecimal previous=line.stock().getQuantity();line.stock().adjust(line.item().getQuantity().negate());
            orderItems.save(new OrderItem(order,line.product(),line.item().getQuantity(),line.product().getPrice()));
            InventoryTransaction transaction=inventoryTransactions.save(new InventoryTransaction(line.product(),customer,line.item().getQuantity().negate(),line.stock().getQuantity(),"ORDER_PLACED",order.getOrderNumber()));
            if(previous.compareTo(line.stock().getMinimumStock())>0&&line.stock().getQuantity().compareTo(line.stock().getMinimumStock())<=0)notificationPublisher.lowStock(line.product(),line.stock().getQuantity(),line.stock().getMinimumStock(),transaction.getId());
        }
        payments.save(new Payment(order,total));
        history.save(new OrderStatusHistory(order,null,OrderStatus.PLACED,customer,"Customer placed COD order"));
        String otp=String.format(Locale.ROOT,"%06d",RANDOM.nextInt(1_000_000));
        otps.save(new DeliveryOtp(order,passwordEncoder.encode(otp),Instant.now().plusSeconds(48*60*60)));
        cartItems.deleteByCart_Id(cart.getId());
        notificationPublisher.orderPlaced(order);
        return response(order,otp);
    }

    @Transactional(readOnly=true) public Page<OrderDtos.OrderResponse> mine(String email,Pageable pageable){AppUser user=customer(email);return orders.findByCustomer_Id(user.getId(),pageable).map(o->response(o,null));}
    @Transactional(readOnly=true) public OrderDtos.OrderResponse getMine(long id,String email){AppUser user=customer(email);CustomerOrder order=orders.findById(id).filter(o->o.getCustomer().getId().equals(user.getId())).orElseThrow(()->notFound("Order not found"));return response(order,null);}
    @Transactional public String rotateDeliveryOtp(long id,String email){AppUser user=customer(email);CustomerOrder order=orders.findById(id).filter(o->o.getCustomer().getId().equals(user.getId())).orElseThrow(()->notFound("Order not found"));
        if(order.getStatus()==OrderStatus.DELIVERED||order.getStatus()==OrderStatus.CANCELLED||order.getStatus()==OrderStatus.REJECTED)throw conflict("This order no longer needs a delivery code");
        DeliveryOtp otp=otps.findLocked(id).orElseThrow(()->notFound("Delivery code not found"));if(otp.isVerified())throw conflict("Delivery has already been verified");
        String code=String.format(Locale.ROOT,"%06d",RANDOM.nextInt(1_000_000));otp.rotate(passwordEncoder.encode(code),Instant.now().plusSeconds(48*60*60));return code;
    }

    @Transactional public OrderDtos.OrderResponse cancelMine(long id,String email,String reason){AppUser customer=customer(email);CustomerOrder order=orders.findLocked(id).filter(o->o.getCustomer().getId().equals(customer.getId())).orElseThrow(()->notFound("Order not found"));
        if(order.getStatus()!=OrderStatus.PLACED)throw conflict("An order can only be cancelled before the shop accepts it");
        String finalReason=reason==null||reason.isBlank()?"Cancelled by customer":reason.trim();
        order.setCancellationReason(finalReason);
        changeStatus(order,OrderStatus.CANCELLED,customer,finalReason);restoreStock(order,customer,"ORDER_CANCELLED");return response(order,null);
    }

    @Transactional public OrderDtos.ReorderResponse reorder(long id,String email){
        AppUser customer=customer(email);CustomerOrder order=orders.findById(id).filter(o->o.getCustomer().getId().equals(customer.getId())).orElseThrow(()->notFound("Order not found"));
        Cart cart=carts.findByCustomer_Id(customer.getId()).orElseGet(()->carts.save(new Cart(customer)));
        List<OrderItem> items=orderItems.findByOrder_IdOrderById(order.getId());
        List<OrderDtos.ReorderItemDetail> details=new ArrayList<>();
        int addedCount=0;int unavailableCount=0;
        for(OrderItem item:items){
            Optional<Product> prodOpt=products.findById(item.getProductId());
            if(prodOpt.isEmpty()||!sellable(prodOpt.get())){
                details.add(new OrderDtos.ReorderItemDetail(item.getProductId(),item.getProductName(),item.getQuantity(),BigDecimal.ZERO,true));
                unavailableCount++;
                continue;
            }
            Product prod=prodOpt.get();
            Inventory stock=inventory.findById(prod.getId()).orElse(null);
            BigDecimal available=stock!=null?stock.getSellableQuantity():BigDecimal.ZERO;
            if(available.compareTo(BigDecimal.ZERO)<=0){
                details.add(new OrderDtos.ReorderItemDetail(prod.getId(),prod.getName(),item.getQuantity(),BigDecimal.ZERO,true));
                unavailableCount++;
                continue;
            }
            CartItem existing=cartItems.findByCart_IdOrderByProduct_Id(cart.getId()).stream().filter(ci->ci.getProduct().getId().equals(prod.getId())).findFirst().orElse(null);
            BigDecimal currentQty=existing!=null?existing.getQuantity():BigDecimal.ZERO;
            BigDecimal canAdd=available.subtract(currentQty).max(BigDecimal.ZERO);
            BigDecimal toAdd=item.getQuantity().min(canAdd);
            if(toAdd.compareTo(BigDecimal.ZERO)>0){
                if(existing==null)cartItems.save(new CartItem(cart,prod,toAdd));else existing.setQuantity(currentQty.add(toAdd));
                details.add(new OrderDtos.ReorderItemDetail(prod.getId(),prod.getName(),item.getQuantity(),toAdd,false));
                addedCount++;
            }else{
                details.add(new OrderDtos.ReorderItemDetail(prod.getId(),prod.getName(),item.getQuantity(),BigDecimal.ZERO,true));
                unavailableCount++;
            }
        }
        var lines=cartItems.findByCart_IdOrderByProduct_Id(cart.getId()).stream().map(ci->{Product p=ci.getProduct();BigDecimal stock=inventory.findById(p.getId()).map(Inventory::getSellableQuantity).orElse(BigDecimal.ZERO);
            BigDecimal total=money(p.getPrice().multiply(ci.getQuantity()));return new OrderDtos.CartLineResponse(ci.getId(),p.getId(),p.getName(),p.getImageUrl(),p.getUnit().name(),p.getPrice(),ci.getQuantity(),stock,total,sellable(p)&&stock.signum()>0);}).toList();
        BigDecimal subtotal=lines.stream().map(OrderDtos.CartLineResponse::lineTotal).reduce(BigDecimal.ZERO,BigDecimal::add);
        return new OrderDtos.ReorderResponse(addedCount,unavailableCount,new OrderDtos.CartResponse(lines,money(subtotal)),details);
    }

    @Transactional(readOnly=true) public Page<OrderDtos.OrderResponse> adminOrders(Pageable pageable){return orders.findAll(pageable).map(o->response(o,null));}
    @Transactional(readOnly=true) public OrderDtos.OrderResponse adminOrder(long id){return response(orders.findById(id).orElseThrow(()->notFound("Order not found")),null);}
    @Transactional public OrderDtos.OrderResponse adminStatus(long id,OrderDtos.OrderStatusRequest request,String email){
        AppUser admin=admin(email);CustomerOrder order=orders.findLocked(id).orElseThrow(()->notFound("Order not found"));OrderStatus next=request.status();
        boolean valid=switch(order.getStatus()){
            case PLACED -> next==OrderStatus.ACCEPTED||next==OrderStatus.REJECTED||next==OrderStatus.CANCELLED;
            case ACCEPTED -> next==OrderStatus.PREPARING||next==OrderStatus.CANCELLED;
            case PREPARING -> next==OrderStatus.READY_FOR_PICKUP||next==OrderStatus.CANCELLED;
            case READY_FOR_PICKUP -> next==OrderStatus.CANCELLED;
            case DELIVERY_FAILED -> next==OrderStatus.READY_FOR_PICKUP||next==OrderStatus.CANCELLED||next==OrderStatus.REJECTED;
            default -> false;
        };
        if(!valid)throw conflict("Invalid order status transition from "+order.getStatus()+" to "+next);
        String finalReason=clean(request.reason());
        if(next==OrderStatus.CANCELLED) {
            order.setCancellationReason(finalReason!=null?finalReason:"Cancelled by admin");
            assignments.findFirstByOrder_IdAndStatusIn(order.getId(),List.of(AssignmentStatus.ASSIGNED,AssignmentStatus.ACCEPTED))
                    .ifPresent(a->a.cancel(finalReason!=null?finalReason:"Order cancelled by admin"));
        }
        changeStatus(order,next,admin,finalReason);if(next==OrderStatus.REJECTED||next==OrderStatus.CANCELLED)restoreStock(order,admin,"ORDER_"+next.name());return response(order,null);
    }

    CustomerOrder lockOrder(long id){return orders.findLocked(id).orElseThrow(()->notFound("Order not found"));}
    CustomerOrder getForAuthorizedDriver(long id){return orders.findById(id).orElseThrow(()->notFound("Order not found"));}
    AppUser requireAdmin(String email){return admin(email);}
    void changeStatus(CustomerOrder order,OrderStatus next,AppUser actor,String reason){OrderStatus old=order.getStatus();order.status(next);history.save(new OrderStatusHistory(order,old,next,actor,reason));notificationPublisher.orderStatus(order,next);}
    void restoreStock(CustomerOrder order,AppUser actor,String reason){
        for(OrderItem line:orderItems.findByOrder_IdOrderById(order.getId())){
            Product product=products.findById(line.getProductId()).orElseThrow(()->notFound("Product not found"));
            Inventory stock=inventory.findLockedByProductId(product.getId()).orElseThrow(()->notFound("Inventory not found"));
            stock.adjust(line.getQuantity());inventoryTransactions.save(new InventoryTransaction(product,actor,line.getQuantity(),stock.getQuantity(),reason,order.getOrderNumber()));
        }
    }
    OrderDtos.OrderResponse response(CustomerOrder order,String deliveryCode){
        var items=orderItems.findByOrder_IdOrderById(order.getId()).stream().map(i->new OrderDtos.OrderItemResponse(i.getProductName(),i.getUnit().name(),i.getQuantity(),i.getUnitPrice(),i.getLineTotal())).toList();
        var events=history.findByOrder_IdOrderByCreatedAtAsc(order.getId()).stream().map(h->new OrderDtos.StatusEvent(h.getFromStatus(),h.getToStatus(),h.getReason(),h.getCreatedAt())).toList();
        OrderDtos.DriverLocationResponse location=null;
        var assignment=assignments.findFirstByOrder_IdAndStatusIn(order.getId(),List.of(AssignmentStatus.ASSIGNED,AssignmentStatus.ACCEPTED,AssignmentStatus.PICKED_UP)).orElse(null);
        if(assignment!=null&&assignment.getStatus()!=AssignmentStatus.DELIVERED){var latest=locations.findByAssignment_IdAndActiveTrue(assignment.getId()).orElse(null);if(latest!=null)location=new OrderDtos.DriverLocationResponse(latest.getLatitude(),latest.getLongitude(),latest.getUpdatedAt());}
        return new OrderDtos.OrderResponse(order.getId(),order.getOrderNumber(),order.getStatus(),"COD",order.getPaymentStatus(),order.getSubtotal(),order.getDeliveryCharge(),order.getTotalAmount(),
                order.getRecipientName(),order.getRecipientPhone(),order.getAddressLine(),order.getHouseNumber(),order.getArea(),order.getLandmark(),order.getPincode(),order.getDeliveryInstructions(),
                order.getDeliveryDate(),order.getDeliverySlot(),order.getCreatedAt(),items,events,deliveryCode,location,order.getIdempotencyKey(),order.getCancellationReason());
    }
    private boolean sellable(Product p){return p.isActive()&&p.isAvailable()&&p.getCategory().isActive();}
    private AppUser customer(String email){return users.findByEmail(email).filter(u->u.getRole()==Role.CUSTOMER&&u.isActive()).orElseThrow(()->new ResponseStatusException(HttpStatus.FORBIDDEN,"Customer account required"));}
    private AppUser admin(String email){return users.findByEmail(email).filter(u->u.getRole()==Role.ADMIN&&u.isActive()).orElseThrow(()->new ResponseStatusException(HttpStatus.FORBIDDEN,"Admin account required"));}
    private String clean(String s){return s==null||s.isBlank()?null:s.trim();}private static BigDecimal money(BigDecimal b){return b.setScale(2,RoundingMode.HALF_UP);}
    private ResponseStatusException notFound(String s){return new ResponseStatusException(HttpStatus.NOT_FOUND,s);}private ResponseStatusException conflict(String s){return new ResponseStatusException(HttpStatus.CONFLICT,s);}private ResponseStatusException badRequest(String s){return new ResponseStatusException(HttpStatus.BAD_REQUEST,s);}
    private record LockedLine(CartItem item,Product product,Inventory stock,BigDecimal total){}
}
