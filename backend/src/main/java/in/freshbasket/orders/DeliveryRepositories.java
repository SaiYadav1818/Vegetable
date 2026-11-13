package in.freshbasket.orders;

import java.util.*;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

interface DriverProfileRepository extends JpaRepository<DriverProfile,Long>{
    Page<DriverProfile> findAll(Pageable pageable);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from DriverProfile d where d.userId=:id")
    Optional<DriverProfile> findLocked(@Param("id") Long userId);
}
interface DriverAssignmentRepository extends JpaRepository<DriverAssignment,Long>{
    Optional<DriverAssignment> findByOrder_Id(Long orderId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select a from DriverAssignment a where a.id=:id") Optional<DriverAssignment> findLocked(@Param("id") Long id);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select a from DriverAssignment a where a.order.id=:id") Optional<DriverAssignment> findLockedByOrderId(@Param("id") Long orderId);
    Page<DriverAssignment> findByDriver_User_Id(Long driverId,Pageable pageable);
    List<DriverAssignment> findByDriver_User_IdAndStatusIn(Long driverId,Collection<AssignmentStatus> statuses);
}
interface DriverLocationRepository extends JpaRepository<DriverLocation,Long>{Optional<DriverLocation> findByAssignment_IdAndActiveTrue(Long assignmentId);}
