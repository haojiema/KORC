program main

use korc_types
use units
use emf
use pic
use main_mpi
use initialize
use finalize

implicit none

	TYPE(KORC_PARAMS) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE :: spp
	TYPE(CHARCS_PARAMS) :: cpp
	TYPE(FIELDS) :: EB
	INTEGER :: it ! Iterator(s)

	call initialize_communications(params)

	! INITIALIZATION STAGE
	call initialize_korc_parameters(params) ! Initialize korc parameters

	call initialize_particles(params,spp) ! Initialize particles

	call initialize_fields(params,EB)

	call compute_charcs_plasma_params(spp,EB,cpp)

	call define_time_step(cpp,params)
	! END OF INITIALIZATION STAGE

	write(6,'("Time step: ",1E10.5)') params%dt

	call normalize_variables(params,spp,EB,cpp)


	! *** *** *** *** *** ***   *** *** *** *** *** *** ***
	! *** BEYOND THIS POINT VARIABLES ARE DIMENSIONLESS ***
	! *** *** *** *** *** ***   *** *** *** *** *** *** ***

	! First particle push
!	call advance_particles_velocity(params,EB,spp,0.5_rp*params%dt)

	do it=1,params%t_steps
		call advance_particles_position(params,EB,spp,params%dt)
		call advance_particles_velocity(params,EB,spp,params%dt)
		if ( modulo(it,params%output_cadence) .EQ. 0 ) then
            write(6,'("Saving variables... ")') 
        end if
	end do


	! DEALLOCATION OF VARIABLES
	call deallocate_variables(params,spp)
	! DEALLOCATION OF VARIABLES

	call finalize_communications(params)

end program main
