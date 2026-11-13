package in.freshbasket.orders;

import in.freshbasket.catalog.*;
import in.freshbasket.user.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CartService {
    private final UserRepository users; private final CartRepository carts; private final CartItemRepository items;
    private final ProductRepository products; private final InventoryRepository inventory;
    public CartService(UserRepository users,CartRepository carts,CartItemRepository items,ProductRepository products,InventoryRepository inventory){this.users=users;this.carts=carts;this.items=items;this.products=products;this.inventory=inventory;}

    @Transactional(readOnly=true) public OrderDtos.CartResponse get(String email){
        var customer=customer(email);var cart=carts.findByCustomer_Id(customer.getId()).orElse(null);
        if(cart==null)return new OrderDtos.CartResponse(java.util.List.of(),money(BigDecimal.ZERO));
        return response(cart);
    }
    @Transactional public OrderDtos.CartResponse add(String email,OrderDtos.CartItemRequest request){
        Cart cart=cart(email);Product product=products.findById(request.productId()).filter(this::sellable).orElseThrow(()->notFound("Product is unavailable"));
        Inventory stock=inventory.findById(product.getId()).orElseThrow(()->notFound("Inventory not found"));
        CartItem existing=items.findByCart_IdOrderByProduct_Id(cart.getId()).stream().filter(i->i.getProduct().getId().equals(product.getId())).findFirst().orElse(null);
        BigDecimal newQuantity=request.quantity().add(existing==null?BigDecimal.ZERO:existing.getQuantity());
        if(newQuantity.compareTo(stock.getQuantity())>0)throw conflict("Requested quantity exceeds current stock");
        if(existing==null)items.save(new CartItem(cart,product,request.quantity()));else existing.setQuantity(newQuantity);
        return response(cart);
    }
    @Transactional public OrderDtos.CartResponse update(String email,long itemId,OrderDtos.CartQuantityRequest request){
        Cart cart=cart(email);CartItem item=items.findByIdAndCart_Id(itemId,cart.getId()).orElseThrow(()->notFound("Cart item not found"));
        Inventory stock=inventory.findById(item.getProduct().getId()).orElseThrow(()->notFound("Inventory not found"));
        if(request.quantity().compareTo(stock.getQuantity())>0)throw conflict("Requested quantity exceeds current stock");
        item.setQuantity(request.quantity());return response(cart);
    }
    @Transactional public void remove(String email,long itemId){Cart cart=cart(email);CartItem item=items.findByIdAndCart_Id(itemId,cart.getId()).orElseThrow(()->notFound("Cart item not found"));items.delete(item);}
    @Transactional public void clear(long cartId){items.deleteByCart_Id(cartId);}
    @Transactional(readOnly=true) public OrderDtos.CartResponse response(Cart cart){
        var lines=items.findByCart_IdOrderByProduct_Id(cart.getId()).stream().map(item->{Product p=item.getProduct();BigDecimal stock=inventory.findById(p.getId()).map(Inventory::getQuantity).orElse(BigDecimal.ZERO);
            BigDecimal total=money(p.getPrice().multiply(item.getQuantity()));return new OrderDtos.CartLineResponse(item.getId(),p.getId(),p.getName(),p.getImageUrl(),p.getUnit().name(),p.getPrice(),item.getQuantity(),stock,total,sellable(p)&&stock.signum()>0);}).toList();
        BigDecimal subtotal=lines.stream().map(OrderDtos.CartLineResponse::lineTotal).reduce(BigDecimal.ZERO,BigDecimal::add);
        return new OrderDtos.CartResponse(lines,money(subtotal));
    }
    private Cart cart(String email){AppUser user=customer(email);return carts.findByCustomer_Id(user.getId()).orElseGet(()->carts.save(new Cart(user)));}
    private AppUser customer(String email){return users.findByEmail(email).filter(u->u.getRole()==Role.CUSTOMER&&u.isActive()).orElseThrow(()->new ResponseStatusException(HttpStatus.FORBIDDEN,"Customer account required"));}
    private boolean sellable(Product p){return p.isActive()&&p.isAvailable()&&p.getCategory().isActive();}
    static BigDecimal money(BigDecimal value){return value.setScale(2,RoundingMode.HALF_UP);}
    private ResponseStatusException notFound(String s){return new ResponseStatusException(HttpStatus.NOT_FOUND,s);}private ResponseStatusException conflict(String s){return new ResponseStatusException(HttpStatus.CONFLICT,s);}
}
