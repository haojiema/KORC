!> @brief Module with subroutines that calculate the characteristic scales in the simulation used in the normalization and nondimensionalization of the simulation variables.
module korc_units
    use korc_types
    use korc_constants

    IMPLICIT NONE

	PUBLIC :: compute_charcs_plasma_params,&
				normalize_variables

    CONTAINS

!> @brief Subroutine that calculates characteristic scales of the current KORC simulation.
!! @details Normalization and non-dimensionalization of the variables and equations of motion allows us to solve them more accurately by reducing truncation erros when performing operations that combine small and large numbers. 
!!
!! For normalizing and obtaining the non-dimensional form of the variables and equations solved in KORC we use characteristic scales calculated with the input data of each KORC simulation.
!! <table>
!! <caption id="multi_row">Characteristic scales in KORC</caption>
!! <tr><th>Characteristic scale		<th>Symbol	<th>Value			<th>Description
!! <tr><td rowspan="1">Velocity <td>@f$v_{ch}@f$	<td>@f$c@f$	<td> Speed of light
!! <tr><td rowspan="1">Magnetic field <td>@f$B_{ch}@f$	<td>@f$B_0@f$	<td> Magnetic field at the magnetic axis
!! <tr><td rowspan="1">Electric field <td>@f$E_{ch}@f$	<td>@f$E_0@f$	<td> Electric field at the magnetic axis
!! <tr><td rowspan="1">Time <td>@f$t_{ch}@f$	<td>@f$\Omega_e = eB_0/m_e@f$ 	<td>
!! <tr><td rowspan="1">Dummy <td>	<td>Dummy	<td>Dummy
!! </table>
!! @param[in,out] params Core KORC simulation parameters.
!! @param[in,out] spp An instance of KORC's derived type SPECIES containing all the information of different electron species. See korc_types.f90.
!! @param[in] F An instance of KORC's derived type FIELDS containing all the information about the fields used in the simulation. See korc_types.f90 and korc_fields.f90.
!! @param ii Index of the spp array containing the mass, electric charge and corresponding cyclotron frequency used to derived some characteristic scales.
subroutine compute_charcs_plasma_params(params,spp,F)
	TYPE(KORC_PARAMS), INTENT(INOUT) 						:: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	TYPE(FIELDS), INTENT(IN) 								:: F
	INTEGER 												:: ii

	params%cpp%velocity = C_C
	params%cpp%Bo = ABS(F%Bo)
	params%cpp%Eo = ABS(params%cpp%velocity*params%cpp%Bo)

	! Non-relativistic cyclotron frequency
	spp(:)%wc = ( ABS(spp(:)%q)/spp(:)%m )*params%cpp%Bo

	! Relativistic cyclotron frequency
	spp(:)%wc_r =  ABS(spp(:)%q)*params%cpp%Bo/( spp(:)%go*spp(:)%m )


	ii = MAXLOC(spp(:)%wc,1) ! Index to maximum cyclotron frequency
	params%cpp%time = 1.0_rp/spp(ii)%wc

	ii = MAXLOC(spp(:)%wc_r,1) ! Index to maximum relativistic cyclotron frequency
	params%cpp%time_r = 1.0_rp/spp(ii)%wc_r

	params%cpp%mass = spp(ii)%m
	params%cpp%charge = ABS(spp(ii)%q)
	params%cpp%length = params%cpp%velocity*params%cpp%time_r
	params%cpp%energy = params%cpp%mass*params%cpp%velocity**2

	params%cpp%density = 1.0_rp/params%cpp%length**3
	params%cpp%pressure = 0.0_rp
	params%cpp%temperature = params%cpp%energy
end subroutine compute_charcs_plasma_params

!> @brief Some brief description... 
!! @param[in,out] params Core KORC simulation parameters.
!! @param[in,out] spp An instance of KORC's derived type SPECIES containing all the information of different electron species. See korc_types.f90.
!! @param[in,out] F An instance of KORC's derived type FIELDS containing all the information about the fields used in the simulation. See korc_types.f90 and korc_fields.f90.
!! @param[in,out] P An instance of KORC's derived type PROFILES containing all the information about the plasma profiles used in the simulation. See korc_types.f90 and korc_profiles.f90.
!! @param ii Interator of spp array.
subroutine normalize_variables(params,spp,F,P)
	TYPE(KORC_PARAMS), INTENT(INOUT) 						:: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	TYPE(FIELDS), INTENT(INOUT) 							:: F
	TYPE(PROFILES), INTENT(INOUT) 							:: P
	INTEGER 												:: ii ! Iterator(s)

!	Normalize params variables
	params%dt = params%dt/params%cpp%time
	params%simulation_time = params%simulation_time/params%cpp%time
	params%snapshot_frequency = params%snapshot_frequency/params%cpp%time
	params%minimum_particle_energy = params%minimum_particle_energy/params%cpp%energy

!	Normalize particle variables
	do ii=1_idef,size(spp)
		spp(ii)%q = spp(ii)%q/params%cpp%charge
		spp(ii)%m = spp(ii)%m/params%cpp%mass
		spp(ii)%Eo = spp(ii)%Eo/params%cpp%energy
		spp(ii)%Eo_lims = spp(ii)%Eo_lims/params%cpp%energy
		spp(ii)%wc = spp(ii)%wc*params%cpp%time
		spp(ii)%wc_r = spp(ii)%wc_r*params%cpp%time
		spp(ii)%vars%X = spp(ii)%vars%X/params%cpp%length
		spp(ii)%vars%V = spp(ii)%vars%V/params%cpp%velocity
		spp(ii)%vars%Rgc = spp(ii)%vars%Rgc/params%cpp%length

		spp(ii)%Ro = spp(ii)%Ro/params%cpp%length
		spp(ii)%Zo = spp(ii)%Zo/params%cpp%length
		spp(ii)%r_inner = spp(ii)%r_inner/params%cpp%length
		spp(ii)%r_outter = spp(ii)%r_outter/params%cpp%length
		spp(ii)%falloff_rate = spp(ii)%falloff_rate*params%cpp%length
	end do

!	Normalize electromagnetic fields and profiles
	F%Bo = F%Bo/params%cpp%Bo
	F%Eo = F%Eo/params%cpp%Eo
	F%Ro = F%Ro/params%cpp%length
	F%Zo = F%Zo/params%cpp%length

	P%a = P%a/params%cpp%length
	P%neo = P%neo/params%cpp%density
	P%Teo = P%Teo/params%cpp%temperature

	if (params%plasma_model .EQ. 'ANALYTICAL') then
		F%AB%Bo = F%AB%Bo/params%cpp%Bo
		F%AB%a = F%AB%a/params%cpp%length
		F%AB%Ro = F%AB%Ro/params%cpp%length
		F%AB%lambda = F%AB%lambda/params%cpp%length
		F%AB%Bpo = F%AB%Bpo/params%cpp%Bo
	else if (params%plasma_model .EQ. 'EXTERNAL') then
		if (ALLOCATED(F%B_3D%R)) F%B_3D%R = F%B_3D%R/params%cpp%Bo
		if (ALLOCATED(F%B_3D%PHI)) F%B_3D%PHI = F%B_3D%PHI/params%cpp%Bo
		if (ALLOCATED(F%B_3D%Z)) F%B_3D%Z = F%B_3D%Z/params%cpp%Bo

		if (ALLOCATED(F%E_3D%R)) F%E_3D%R = F%E_3D%R/params%cpp%Eo
		if (ALLOCATED(F%E_3D%PHI)) F%E_3D%PHI = F%E_3D%PHI/params%cpp%Eo
		if (ALLOCATED(F%E_3D%Z)) F%E_3D%Z = F%E_3D%Z/params%cpp%Eo

		if (ALLOCATED(F%PSIp)) F%PSIp = F%PSIp/(params%cpp%Bo*params%cpp%length**2)

		if (ALLOCATED(F%B_2D%R)) F%B_2D%R = F%B_2D%R/params%cpp%Bo
		if (ALLOCATED(F%B_2D%PHI)) F%B_2D%PHI = F%B_2D%PHI/params%cpp%Bo
		if (ALLOCATED(F%B_2D%Z)) F%B_2D%Z = F%B_2D%Z/params%cpp%Bo

		if (ALLOCATED(F%E_2D%R)) F%E_2D%R = F%E_2D%R/params%cpp%Eo
		if (ALLOCATED(F%E_2D%PHI)) F%E_2D%PHI = F%E_2D%PHI/params%cpp%Eo
		if (ALLOCATED(F%E_2D%Z)) F%E_2D%Z = F%E_2D%Z/params%cpp%Eo

		F%X%R = F%X%R/params%cpp%length
		! Nothing to do for the PHI component
		F%X%Z = F%X%Z/params%cpp%length

		if (params%collisions) then
			P%X%R = P%X%R/params%cpp%length
			P%X%Z = P%X%Z/params%cpp%length

			if (ALLOCATED(P%ne_2D)) P%ne_2D = P%ne_2D/params%cpp%density
			if (ALLOCATED(P%Te_2D)) P%Te_2D = P%Te_2D/params%cpp%temperature

			if (ALLOCATED(P%ne_3D)) P%ne_3D = P%ne_3D/params%cpp%density
			if (ALLOCATED(P%Te_3D)) P%Te_3D = P%Te_3D/params%cpp%temperature
		end if
	else if (params%plasma_model .EQ. 'UNIFORM') then
		F%Eo = F%Eo/params%cpp%Eo
	end if	
end subroutine normalize_variables

end module korc_units
