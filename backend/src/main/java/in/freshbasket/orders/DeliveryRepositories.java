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
    Optional<DriverAssignment> findFirstByOrder_IdOrderByAssignedAtDesc(Long orderId);
    Optional<DriverAssignment> findFirstByOrder_IdAndStatusIn(Long orderId,Collection<AssignmentStatus> statuses);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select a from DriverAssignment a where a.id=:id") Optional<DriverAssignment> findLocked(@Param("id") Long id);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select a from DriverAssignment a where a.order.id=:id and a.status in :statuses")
    Optional<DriverAssignment> findLockedByOrderIdAndStatusIn(@Param("id") Long orderId,@Param("statuses") Collection<AssignmentStatus> statuses);
    Page<DriverAssignment> findByDriver_User_Id(Long driverId,Pageable pageable);
    List<DriverAssignment> findByDriver_User_IdAndStatusIn(Long driverId,Collection<AssignmentStatus> statuses);
    List<DriverAssignment> findByOrder_IdOrderByAssignedAtAsc(Long orderId);
}
interface DriverLocationRepository extends JpaRepository<DriverLocation,Long>{Optional<DriverLocation> findByAssignment_IdAndActiveTrue(Long assignmentId);}
