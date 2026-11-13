package in.freshbasket.orders;

import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/cart") @PreAuthorize("hasRole('CUSTOMER')")
public class CartController {
    private final CartService cart;
    public CartController(CartService cart){this.cart=cart;}
    @GetMapping public OrderDtos.CartResponse get(Authentication auth){return cart.get(auth.getName());}
    @PostMapping("/items") public OrderDtos.CartResponse add(Authentication auth,@Valid @RequestBody OrderDtos.CartItemRequest request){return cart.add(auth.getName(),request);}
    @PutMapping("/items/{id}") public OrderDtos.CartResponse update(Authentication auth,@PathVariable long id,@Valid @RequestBody OrderDtos.CartQuantityRequest request){return cart.update(auth.getName(),id,request);}
    @DeleteMapping("/items/{id}") public void remove(Authentication auth,@PathVariable long id){cart.remove(auth.getName(),id);}
}
