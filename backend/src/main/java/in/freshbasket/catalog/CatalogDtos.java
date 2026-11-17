package in.freshbasket.catalog;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;

public final class CatalogDtos {
    private CatalogDtos(){}
    public record CategoryRequest(@NotBlank @Size(max=80) String name,@Size(max=300) String description){}
    public record CategoryResponse(Long id,String name,String description,boolean active){}
    public record ProductRequest(@NotBlank @Size(max=120) String name,@Size(max=1000) String description,@NotNull Long categoryId,
            @NotNull @DecimalMin(value="0.01") @Digits(integer=8,fraction=2) BigDecimal price,@NotNull ProductUnit unit,
            @Size(max=500) String imageUrl,boolean active,boolean available,
            @NotNull @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal initialStock,
            @NotNull @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal minimumStock,
            @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal safetyStockBuffer){
        public ProductRequest(String name, String description, Long categoryId, BigDecimal price, ProductUnit unit,
                              String imageUrl, boolean active, boolean available, BigDecimal initialStock, BigDecimal minimumStock) {
            this(name, description, categoryId, price, unit, imageUrl, active, available, initialStock, minimumStock, BigDecimal.ZERO);
        }
    }
    public record ProductUpdateRequest(@NotBlank @Size(max=120) String name,@Size(max=1000) String description,@NotNull Long categoryId,
            @NotNull @DecimalMin(value="0.01") @Digits(integer=8,fraction=2) BigDecimal price,@NotNull ProductUnit unit,
            @Size(max=500) String imageUrl,boolean active,boolean available,
            @NotNull @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal minimumStock,
            @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal safetyStockBuffer){
        public ProductUpdateRequest(String name, String description, Long categoryId, BigDecimal price, ProductUnit unit,
                                    String imageUrl, boolean active, boolean available, BigDecimal minimumStock) {
            this(name, description, categoryId, price, unit, imageUrl, active, available, minimumStock, null);
        }
    }
    public record ProductResponse(Long id,String name,String description,Long categoryId,String categoryName,BigDecimal price,
            ProductUnit unit,String imageUrl,boolean active,boolean available,BigDecimal stock,BigDecimal minimumStock,
            BigDecimal safetyStockBuffer,BigDecimal sellableStock){
        public ProductResponse(Long id,String name,String description,Long categoryId,String categoryName,BigDecimal price,
                ProductUnit unit,String imageUrl,boolean active,boolean available,BigDecimal stock,BigDecimal minimumStock) {
            this(id, name, description, categoryId, categoryName, price, unit, imageUrl, active, available, stock, minimumStock, BigDecimal.ZERO, stock);
        }
    }
    public record InventoryAdjustment(@NotNull @DecimalMin(value="-999999999.999") @Digits(integer=9,fraction=3) BigDecimal delta,
            @NotBlank @Size(max=40) String reason,@Size(max=300) String note,
            @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal minimumStock,
            @DecimalMin("0.000") @Digits(integer=9,fraction=3) BigDecimal safetyStockBuffer){
        public InventoryAdjustment(BigDecimal delta, String reason, String note, BigDecimal minimumStock) {
            this(delta, reason, note, minimumStock, null);
        }
    }
    public record InventoryTransactionResponse(Long id,BigDecimal quantityDelta,BigDecimal quantityAfter,String reason,String note,Instant createdAt){}
}
