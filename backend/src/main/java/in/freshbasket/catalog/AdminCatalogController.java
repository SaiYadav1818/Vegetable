package in.freshbasket.catalog;

import jakarta.validation.Valid;
import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController @RequestMapping("/api/admin")
public class AdminCatalogController {
    private final CatalogService catalog;
    private final ProductImageStorage imageStorage;
    public AdminCatalogController(CatalogService catalog,ProductImageStorage imageStorage){this.catalog=catalog;this.imageStorage=imageStorage;}
    @PostMapping("/categories") public CatalogDtos.CategoryResponse createCategory(@Valid @RequestBody CatalogDtos.CategoryRequest request){return catalog.createCategory(request);}
    @PutMapping("/categories/{id}") public CatalogDtos.CategoryResponse updateCategory(@PathVariable long id,@Valid @RequestBody CatalogDtos.CategoryRequest request){return catalog.updateCategory(id,request);}
    @DeleteMapping("/categories/{id}") public void deactivateCategory(@PathVariable long id){catalog.deactivateCategory(id);}
    @GetMapping("/products") public Page<CatalogDtos.ProductResponse> products(@PageableDefault(size=20,sort="name") Pageable pageable){return catalog.adminProducts(pageable);}
    @PostMapping("/products") public CatalogDtos.ProductResponse createProduct(@Valid @RequestBody CatalogDtos.ProductRequest request,Authentication auth){return catalog.createProduct(request,auth.getName());}
    @PutMapping("/products/{id}") public CatalogDtos.ProductResponse updateProduct(@PathVariable long id,@Valid @RequestBody CatalogDtos.ProductUpdateRequest request){return catalog.updateProduct(id,request);}
    @DeleteMapping("/products/{id}") public void deactivateProduct(@PathVariable long id){catalog.deactivateProduct(id);}
    @PostMapping(value="/products/{id}/image",consumes="multipart/form-data") public CatalogDtos.ProductResponse uploadImage(@PathVariable long id,@RequestPart("file") MultipartFile file){return catalog.setProductImage(id,imageStorage.store(file));}
    @PostMapping("/products/{id}/inventory-adjustments") public CatalogDtos.ProductResponse adjustInventory(@PathVariable long id,@Valid @RequestBody CatalogDtos.InventoryAdjustment request,Authentication auth){return catalog.adjustInventory(id,request,auth.getName());}
    @GetMapping("/products/{id}/inventory-history") public Page<CatalogDtos.InventoryTransactionResponse> history(@PathVariable long id,@PageableDefault(size=50,sort="createdAt",direction=Sort.Direction.DESC) Pageable pageable){return catalog.history(id,pageable);}
}
