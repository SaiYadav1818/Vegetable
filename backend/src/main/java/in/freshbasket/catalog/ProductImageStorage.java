package in.freshbasket.catalog;

import java.io.IOException;
import java.nio.file.*;
import java.util.Iterator;
import java.util.UUID;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class ProductImageStorage {
    private static final long MAX_BYTES=5L*1024*1024;
    private final Path directory;
    public ProductImageStorage(@Value("${app.upload-dir:./uploads}") String dir){directory=Path.of(dir).toAbsolutePath().normalize();}
    public String store(MultipartFile file){
        if(file.isEmpty()||file.getSize()>MAX_BYTES)throw badRequest("Image must be between 1 byte and 5 MB");
        try {
            byte[] bytes=file.getBytes();
            String extension=validImageExtension(bytes);
            Path target=directory.resolve(UUID.randomUUID()+"."+extension).normalize();
            if(!target.getParent().equals(directory))throw badRequest("Invalid image file name");
            Files.createDirectories(directory);Files.write(target,bytes,StandardOpenOption.CREATE_NEW);
            return "/uploads/"+target.getFileName();
        } catch(ResponseStatusException e){throw e;} catch(IOException e){throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,"Could not store product image");}
    }
    private String validImageExtension(byte[] bytes){
        boolean png=bytes.length>8&&(bytes[0]&255)==137&&bytes[1]==80&&bytes[2]==78&&bytes[3]==71&&bytes[4]==13&&bytes[5]==10&&bytes[6]==26&&bytes[7]==10;
        boolean jpeg=bytes.length>3&&(bytes[0]&255)==255&&(bytes[1]&255)==216&&(bytes[2]&255)==255;
        if(!png&&!jpeg)throw badRequest("Only valid PNG or JPEG images are supported");
        try(ImageInputStream input=ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))){
            Iterator<ImageReader> readers=ImageIO.getImageReaders(input);if(!readers.hasNext())throw badRequest("Invalid image content");
            ImageReader reader=readers.next();try{reader.setInput(input,true,true);long pixels=(long)reader.getWidth(0)*reader.getHeight(0);if(pixels<=0||pixels>25_000_000L)throw badRequest("Image dimensions exceed the 25 megapixel limit");}
            finally{reader.dispose();}
        }catch(IOException e){throw badRequest("Invalid image content");}
        return png?"png":"jpg";
    }
    private ResponseStatusException badRequest(String message){return new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
}
