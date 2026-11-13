package in.freshbasket.orders;

import jakarta.validation.Valid;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/driver") @PreAuthorize("hasRole('DRIVER')")
public class DriverOrdersController {
    private final DeliveryService delivery;
    public DriverOrdersController(DeliveryService delivery){this.delivery=delivery;}
    @GetMapping("/orders") public Page<OrderDtos.DriverOrderResponse> orders(Authentication auth,@PageableDefault(size=30,sort="assignedAt",direction=Sort.Direction.DESC) Pageable pageable){return delivery.assigned(auth.getName(),pageable);}
    @GetMapping("/orders/{id}") public OrderDtos.OrderResponse getOrder(Authentication auth,@PathVariable long id){return delivery.assignedOrder(id,auth.getName());}
    @PutMapping("/orders/{id}/accept") public OrderDtos.DriverOrderResponse accept(Authentication auth,@PathVariable long id){return delivery.accept(id,auth.getName());}
    @PutMapping("/orders/{id}/pickup") public OrderDtos.DriverOrderResponse pickup(Authentication auth,@PathVariable long id){return delivery.pickup(id,auth.getName());}
    @PutMapping("/orders/{id}/fail") public OrderDtos.DriverOrderResponse fail(Authentication auth,@PathVariable long id,@Valid @RequestBody OrderDtos.DeliveryFailRequest request){return delivery.fail(id,auth.getName(),request);}
    @PutMapping("/orders/{id}/deliver") public OrderDtos.OrderResponse deliver(Authentication auth,@PathVariable long id,@Valid @RequestBody OrderDtos.DeliverRequest request){return delivery.deliver(id,auth.getName(),request);}
    @PutMapping("/availability") public void availability(Authentication auth,@Valid @RequestBody OrderDtos.AvailabilityRequest request){delivery.availability(auth.getName(),request.online());}
    @PostMapping("/location") public void location(Authentication auth,@Valid @RequestBody OrderDtos.DriverLocationRequest request){delivery.location(auth.getName(),request);}
}
