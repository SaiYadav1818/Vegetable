package in.freshbasket.catalog;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
public interface ProductRepository extends JpaRepository<Product,Long>{
    @Query("select p from Product p where p.active=true and p.available=true and p.category.active=true")
    Page<Product> findAvailable(Pageable pageable);
    @Query("select p from Product p where p.active=true and p.available=true and p.category.active=true and p.category.id=:categoryId")
    Page<Product> findAvailableInCategory(@Param("categoryId") Long categoryId,Pageable pageable);
}
