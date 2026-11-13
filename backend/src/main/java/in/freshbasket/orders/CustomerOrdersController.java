package in.freshbasket.orders;

import jakarta.validation.Valid;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/orders") @PreAuthorize("hasRole('CUSTOMER')")
public class CustomerOrdersController {
    private final OrderService orders;
    public CustomerOrdersController(OrderService orders){this.orders=orders;}
    @PostMapping public OrderDtos.OrderResponse place(Authentication auth,@Valid @RequestBody OrderDtos.CheckoutRequest request){return orders.place(auth.getName(),request);}
    @GetMapping("/my") public Page<OrderDtos.OrderResponse> mine(Authentication auth,@PageableDefault(size=20,sort="createdAt",direction=Sort.Direction.DESC) Pageable pageable){return orders.mine(auth.getName(),pageable);}
    @GetMapping("/{id}") public OrderDtos.OrderResponse get(Authentication auth,@PathVariable long id){return orders.getMine(id,auth.getName());}
    @PostMapping("/{id}/cancel") public OrderDtos.OrderResponse cancel(Authentication auth,@PathVariable long id,@RequestBody(required=false) OrderDtos.CancelRequest request){return orders.cancelMine(id,auth.getName(),request==null?null:request.reason());}
    @PostMapping("/{id}/delivery-otp") public OrderDtos.DeliveryCodeResponse rotateOtp(Authentication auth,@PathVariable long id){return new OrderDtos.DeliveryCodeResponse(orders.rotateDeliveryOtp(id,auth.getName()));}
}
