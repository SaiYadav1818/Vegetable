package in.freshbasket.catalog;

import org.springframework.data.domain.*;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.*;

@RestController
public class PublicCatalogController {
    private final CatalogService catalog;
    public PublicCatalogController(CatalogService catalog){this.catalog=catalog;}
    @GetMapping("/api/categories") public java.util.List<CatalogDtos.CategoryResponse> categories(){return catalog.categories();}
    @GetMapping("/api/products") public Page<CatalogDtos.ProductResponse> products(@RequestParam(required=false) Long categoryId,
            @PageableDefault(size=20,sort="name") Pageable pageable){return catalog.products(categoryId,pageable);}
    @GetMapping("/api/products/{id}") public CatalogDtos.ProductResponse product(@PathVariable long id){return catalog.getProduct(id);}
}
