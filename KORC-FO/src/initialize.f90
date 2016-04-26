module initialize
use korc_types
#ifdef WITH_MPI
use mpi
#endif

implicit none
INTEGER, PRIVATE :: str_length
CHARACTER(MAX_STRING_LENGTH), PRIVATE :: aux_str
contains

subroutine set_paths(params)
implicit none
INTEGER :: argn
TYPE(KORC_PARAMS), INTENT(OUT) :: params

argn = command_argument_count()
call get_command_argument(1,params%path_to_inputs)
call get_command_argument(2,params%path_to_outputs)
! write(6,*) argn
! write(6,*) TRIM(params%path_to_inputs), LEN(params%path_to_inputs)
! write(6,*) TRIM(params%path_to_outputs), LEN(params%path_to_outputs)
end subroutine set_paths


subroutine load_korc_params(params)
implicit none
TYPE (KORC_PARAMS), INTENT(INOUT) :: params

! LOGICAL :: restart
INTEGER :: t_steps
REAL :: DT
! CHARACTER(MAX_STRING_LENGTH) :: magnetic_field_model
INTEGER :: output_cadence
INTEGER :: num_species

NAMELIST /input_parameters/ t_steps,DT,output_cadence,num_species
	
open(unit=101,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
read(101,nml=input_parameters)
close(101)
	
! params%restart = restart
params%t_steps = t_steps
params%DT = DT
! params%magnetic_field_model = TRIM(magnetic_field_model)
params%output_cadence = output_cadence
params%num_species = num_species

end subroutine load_korc_params

subroutine initialize_communications(params)
implicit none
TYPE(KORC_PARAMS), INTENT(OUT) :: params
INTEGER :: ierr

#ifdef WITH_MPI
call MPI_INIT(ierr)
if (ierr .NE. MPI_SUCCESS) then
    print *,'Error starting MPI program. Terminating.'
    call MPI_ABORT(MPI_COMM_WORLD, -10, ierr)
end if
#endif
end subroutine initialize_communications


subroutine initialize_korc_parameters(params)
use korc_types
implicit none
TYPE(KORC_PARAMS), INTENT(OUT) :: params

call set_paths(params)
! call set_cluster_params(params)
call load_korc_params(params)    

end subroutine initialize_korc_parameters



end module initialize