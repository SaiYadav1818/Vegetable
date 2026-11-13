package in.freshbasket.orders;

import jakarta.validation.Valid;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/admin") @PreAuthorize("hasRole('ADMIN')")
public class AdminOrdersController {
    private final OrderService orders; private final DeliveryService delivery;
    public AdminOrdersController(OrderService orders,DeliveryService delivery){this.orders=orders;this.delivery=delivery;}
    @GetMapping("/orders") public Page<OrderDtos.OrderResponse> orders(@PageableDefault(size=20,sort="createdAt",direction=Sort.Direction.DESC) Pageable pageable){return orders.adminOrders(pageable);}
    @GetMapping("/orders/{id}") public OrderDtos.OrderResponse order(@PathVariable long id){return orders.adminOrder(id);}
    @PutMapping("/orders/{id}/status") public OrderDtos.OrderResponse status(@PathVariable long id,@Valid @RequestBody OrderDtos.OrderStatusRequest request,Authentication auth){return orders.adminStatus(id,request,auth.getName());}
    @PostMapping("/orders/{id}/assign-driver") public OrderDtos.OrderResponse assign(@PathVariable long id,@Valid @RequestBody OrderDtos.AssignDriverRequest request,Authentication auth){return delivery.assign(id,request.driverUserId(),auth.getName());}
    @PostMapping("/drivers") public OrderDtos.DriverResponse createDriver(@Valid @RequestBody OrderDtos.DriverCreateRequest request,Authentication auth){return delivery.createDriver(auth.getName(),request);}
    @GetMapping("/drivers") public Page<OrderDtos.DriverResponse> drivers(@PageableDefault(size=50,sort="user.fullName") Pageable pageable){return delivery.drivers(pageable);}
}
