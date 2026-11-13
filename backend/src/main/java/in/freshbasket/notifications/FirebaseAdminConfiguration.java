package in.freshbasket.notifications;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(prefix="app.firebase",name="enabled",havingValue="true")
public class FirebaseAdminConfiguration {
    @Bean
    FirebaseApp firebaseApp(@Value("${app.firebase.credentials}") String credentialsPath,
            @Value("${app.firebase.project-id:}") String projectId) throws Exception {
        Path path=Path.of(credentialsPath).toAbsolutePath().normalize();
        try(InputStream input=Files.newInputStream(path)) {
            FirebaseOptions.Builder options=FirebaseOptions.builder().setCredentials(GoogleCredentials.fromStream(input));
            if(!projectId.isBlank()) options.setProjectId(projectId);
            return FirebaseApp.initializeApp(options.build());
        }
    }
    @Bean FirebaseMessaging firebaseMessaging(FirebaseApp app){return FirebaseMessaging.getInstance(app);}
}
