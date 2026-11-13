package in.freshbasket.catalog;

import in.freshbasket.user.UserRepository;
import java.math.BigDecimal;
import java.net.URI;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CatalogService {
    private final CategoryRepository categories; private final ProductRepository products; private final InventoryRepository inventory;
    private final InventoryTransactionRepository transactions; private final UserRepository users;
    public CatalogService(CategoryRepository categories,ProductRepository products,InventoryRepository inventory,InventoryTransactionRepository transactions,UserRepository users){this.categories=categories;this.products=products;this.inventory=inventory;this.transactions=transactions;this.users=users;}

    @Transactional(readOnly=true) public java.util.List<CatalogDtos.CategoryResponse> categories(){return categories.findByActiveTrueOrderByNameAsc().stream().map(this::categoryDto).toList();}
    @Transactional public CatalogDtos.CategoryResponse createCategory(CatalogDtos.CategoryRequest r){String name=r.name().trim();if(categories.existsByNameIgnoreCase(name))throw conflict("Category name already exists");return categoryDto(categories.save(new Category(name,clean(r.description()))));}
    @Transactional public CatalogDtos.CategoryResponse updateCategory(long id,CatalogDtos.CategoryRequest r){Category c=category(id);if(categories.existsByNameIgnoreCaseAndIdNot(r.name().trim(),id))throw conflict("Category name already exists");c.update(r.name().trim(),clean(r.description()),true);return categoryDto(c);}
    @Transactional public void deactivateCategory(long id){Category c=category(id);c.update(c.getName(),c.getDescription(),false);}

    @Transactional(readOnly=true) public Page<CatalogDtos.ProductResponse> products(Long categoryId,Pageable pageable){
        Page<Product> result=categoryId==null?products.findAvailable(pageable):products.findAvailableInCategory(categoryId,pageable);
        return result.map(this::productDto);
    }
    @Transactional(readOnly=true) public Page<CatalogDtos.ProductResponse> adminProducts(Pageable pageable){return products.findAll(pageable).map(this::productDto);}
    @Transactional(readOnly=true) public CatalogDtos.ProductResponse getProduct(long id){Product p=products.findById(id).filter(Product::isActive).filter(x->x.getCategory().isActive()).orElseThrow(()->notFound("Product not found"));return productDto(p);}
    @Transactional public CatalogDtos.ProductResponse createProduct(CatalogDtos.ProductRequest r,String actorEmail){
        Category category=category(r.categoryId());if(!category.isActive())throw badRequest("Cannot add a product to an inactive category");validateImage(r.imageUrl());
        Product product=products.save(new Product(r.name().trim(),clean(r.description()),category,r.price(),r.unit(),clean(r.imageUrl())));
        product.update(r.name().trim(),clean(r.description()),category,r.price(),r.unit(),clean(r.imageUrl()),r.active(),r.available());
        Inventory stock=inventory.save(new Inventory(product,r.initialStock(),r.minimumStock()));
        if(r.initialStock().signum()!=0)transactions.save(new InventoryTransaction(product,actor(actorEmail),r.initialStock(),stock.getQuantity(),"INITIAL_STOCK","Initial inventory"));
        return productDto(product);
    }
    @Transactional public CatalogDtos.ProductResponse updateProduct(long id,CatalogDtos.ProductUpdateRequest r){
        Product p=products.findById(id).orElseThrow(()->notFound("Product not found"));Category c=category(r.categoryId());if(!c.isActive())throw badRequest("Cannot assign a product to an inactive category");validateImage(r.imageUrl());
        p.update(r.name().trim(),clean(r.description()),c,r.price(),r.unit(),clean(r.imageUrl()),r.active(),r.available());
        Inventory i=inventory.findById(id).orElseThrow(()->notFound("Inventory not found"));i.minimumStock(r.minimumStock());
        return productDto(p);
    }
    @Transactional public void deactivateProduct(long id){Product p=products.findById(id).orElseThrow(()->notFound("Product not found"));p.deactivate();}
    @Transactional public CatalogDtos.ProductResponse setProductImage(long id,String imageUrl){Product p=products.findById(id).orElseThrow(()->notFound("Product not found"));p.imageUrl(imageUrl);return productDto(p);}
    @Transactional public CatalogDtos.ProductResponse adjustInventory(long id,CatalogDtos.InventoryAdjustment r,String actorEmail){
        Product p=products.findById(id).orElseThrow(()->notFound("Product not found"));Inventory i=inventory.findLockedByProductId(id).orElseThrow(()->notFound("Inventory not found"));
        BigDecimal next=i.getQuantity().add(r.delta());if(next.signum()<0)throw badRequest("Inventory cannot be reduced below zero");
        i.adjust(r.delta());if(r.minimumStock()!=null)i.minimumStock(r.minimumStock());
        if(r.delta().signum()!=0)transactions.save(new InventoryTransaction(p,actor(actorEmail),r.delta(),next,r.reason().trim(),clean(r.note())));
        return productDto(p);
    }
    @Transactional(readOnly=true) public Page<CatalogDtos.InventoryTransactionResponse> history(long productId,Pageable pageable){if(!products.existsById(productId))throw notFound("Product not found");return transactions.findByProduct_Id(productId,pageable).map(t->new CatalogDtos.InventoryTransactionResponse(t.getId(),t.getQuantityDelta(),t.getQuantityAfter(),t.getReason(),t.getNote(),t.getCreatedAt()));}
    private CatalogDtos.ProductResponse productDto(Product p){Inventory i=inventory.findById(p.getId()).orElseThrow(()->notFound("Inventory not found"));return new CatalogDtos.ProductResponse(p.getId(),p.getName(),p.getDescription(),p.getCategory().getId(),p.getCategory().getName(),p.getPrice(),p.getUnit(),p.getImageUrl(),p.isActive(),p.isAvailable(),i.getQuantity(),i.getMinimumStock());}
    private CatalogDtos.CategoryResponse categoryDto(Category c){return new CatalogDtos.CategoryResponse(c.getId(),c.getName(),c.getDescription(),c.isActive());}
    private Category category(Long id){return categories.findById(id).orElseThrow(()->notFound("Category not found"));}
    private in.freshbasket.user.AppUser actor(String email){return users.findByEmail(email).orElseThrow(()->notFound("Admin account not found"));}
    private String clean(String value){return value==null||value.isBlank()?null:value.trim();}
    private void validateImage(String value){if(value==null||value.isBlank())return;try{URI uri=URI.create(value);if(!("https".equalsIgnoreCase(uri.getScheme())||"http".equalsIgnoreCase(uri.getScheme()))||uri.getHost()==null)throw badRequest("Image URL must be an absolute HTTP(S) URL");}catch(IllegalArgumentException e){throw badRequest("Image URL must be an absolute HTTP(S) URL");}}
    private ResponseStatusException notFound(String s){return new ResponseStatusException(HttpStatus.NOT_FOUND,s);}private ResponseStatusException conflict(String s){return new ResponseStatusException(HttpStatus.CONFLICT,s);}private ResponseStatusException badRequest(String s){return new ResponseStatusException(HttpStatus.BAD_REQUEST,s);}
}
