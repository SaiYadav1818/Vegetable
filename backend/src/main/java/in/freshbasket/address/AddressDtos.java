package in.freshbasket.address;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.Instant;

public class AddressDtos {
    public record AddressResponse(
            Long id,
            String label,
            String recipientName,
            String recipientPhone,
            String addressLine,
            String houseNumber,
            String area,
            String landmark,
            String pincode,
            boolean isDefault,
            Instant createdAt
    ) {
        public static AddressResponse from(CustomerAddress a) {
            return new AddressResponse(
                    a.getId(),
                    a.getLabel(),
                    a.getRecipientName(),
                    a.getRecipientPhone(),
                    a.getAddressLine(),
                    a.getHouseNumber(),
                    a.getArea(),
                    a.getLandmark(),
                    a.getPincode(),
                    a.isDefault(),
                    a.getCreatedAt()
            );
        }
    }

    public record CreateAddressRequest(
            String label,
            @NotBlank String recipientName,
            @NotBlank @Pattern(regexp = "^[0-9]{10}$", message = "Phone must be 10 digits") String recipientPhone,
            @NotBlank String addressLine,
            String houseNumber,
            @NotBlank String area,
            String landmark,
            @NotBlank @Pattern(regexp = "^[0-9]{6}$", message = "Pincode must be 6 digits") String pincode,
            Boolean isDefault
    ) {}

    public record UpdateAddressRequest(
            String label,
            @NotBlank String recipientName,
            @NotBlank @Pattern(regexp = "^[0-9]{10}$", message = "Phone must be 10 digits") String recipientPhone,
            @NotBlank String addressLine,
            String houseNumber,
            @NotBlank String area,
            String landmark,
            @NotBlank @Pattern(regexp = "^[0-9]{6}$", message = "Pincode must be 6 digits") String pincode,
            Boolean isDefault
    ) {}
}
