module korc_units

    use korc_types
    use constants

    implicit none

	PUBLIC :: compute_charcs_plasma_params, define_time_step, normalize_variables

    contains

subroutine compute_charcs_plasma_params(spp,F,cpp)
    implicit none
	TYPE(CHARCS_PARAMS), INTENT(INOUT) :: cpp
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	TYPE(FIELDS), INTENT(IN) :: F
	INTEGER :: ind

	cpp%velocity = C_C
	cpp%magnetic_field = F%Bo

	! Non-relativistic cyclotron frequency
	spp(:)%wc = ( abs(spp(:)%q)/spp(:)%m )*cpp%magnetic_field

	! Relativistic cyclotron frequency
	spp(:)%wc_r =  abs(spp(:)%q)*cpp%magnetic_field/( spp(:)%gammao*spp(:)%m )


	ind = maxloc(spp(:)%wc,1) ! Index to maximum cyclotron frequency
	cpp%time = 2.0_rp*C_PI/spp(ind)%wc

	ind = maxloc(spp(:)%wc_r,1) ! Index to maximum relativistic cyclotron frequency
	cpp%time_r = 2.0_rp*C_PI/spp(ind)%wc_r

	cpp%mass = spp(ind)%m
	cpp%charge = abs(spp(ind)%q)
	cpp%length = cpp%velocity*cpp%time
	cpp%energy = cpp%mass*(cpp%velocity**2)

	cpp%density = 0.0_rp
	cpp%electric_field = 0.0_rp
	cpp%pressure = 0.0_rp
	cpp%temperature = 0.0_rp
end subroutine compute_charcs_plasma_params


subroutine define_time_step(cpp,params)
    implicit none
	TYPE(KORC_PARAMS), INTENT(OUT) :: params
	TYPE(CHARCS_PARAMS), INTENT(IN) :: cpp

! 	This definition will be changed as more species and electromagnetic fields
!	are included.

	params%dt = params%dt*cpp%time_r

end subroutine define_time_step


subroutine normalize_variables(params,spp,F,cpp)
    implicit none
	TYPE(KORC_PARAMS), INTENT(INOUT) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	TYPE(FIELDS), INTENT(INOUT) :: F
	TYPE(CHARCS_PARAMS), INTENT(IN) :: cpp
	INTEGER :: ii ! Iterator(s)

!	Normalize params variables
	params%dt = params%dt/cpp%time

!	Normalize particle variables
	do ii=1,size(spp)
		spp(ii)%q = spp(ii)%q/cpp%charge
		spp(ii)%m = spp(ii)%m/cpp%mass
		spp(ii)%Eo = spp(ii)%Eo/cpp%energy
		spp(ii)%wc = spp(ii)%wc*cpp%time
		spp(ii)%vars%X = spp(ii)%vars%X/cpp%length
		spp(ii)%vars%V = spp(ii)%vars%V/cpp%velocity
		spp(ii)%vars%Rgc = spp(ii)%vars%Rgc/cpp%length
	end do

!	Normalize electromagnetic fields
	if (params%magnetic_field_model .EQ. 'ANALYTICAL') then
		F%Bo = F%Bo/cpp%magnetic_field

		F%AB%Bo = F%AB%Bo/cpp%magnetic_field
		F%AB%a = F%AB%a/cpp%length
		F%AB%Ro = F%AB%Ro/cpp%length
		F%AB%lambda = F%AB%lambda/cpp%length
		F%AB%Bpo = F%AB%Bpo/cpp%magnetic_field
	else
		F%Bo = F%Bo/cpp%magnetic_field

		F%B%R = F%B%R/cpp%magnetic_field
		F%B%PHI = F%B%PHI/cpp%magnetic_field
		F%B%Z = F%B%Z/cpp%magnetic_field

		F%X%R = F%X%R/cpp%length
		! Nothing to do for the PHI component
		F%X%Z = F%X%Z/cpp%length
	end if

!	Normalize other variables
		C_Ke = C_Ke/( cpp%mass*cpp%length*cpp%velocity**2/cpp%charge**2 )
!		.
!		.
end subroutine normalize_variables

end module korc_units
