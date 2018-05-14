MODULE korc_velocity_distribution
	USE korc_types
	USE korc_constants
	USE korc_HDF5
	USE korc_hpc
    use korc_fields
    use korc_rnd_numbers
	use korc_hammersley_generator

	use korc_avalanche ! external module
	use korc_experimental_pdf ! external module
	use korc_energy_pdfs ! external module
	use korc_simple_equilibrium_pdf ! external module

	IMPLICIT NONE

	PUBLIC :: initial_velocity_distribution,&
				thermal_distribution,&
				initial_energy_pitch_dist
	PRIVATE :: fth_3V,&
				fth_1V,&
				random_norm,&
				gyro_distribution

	CONTAINS

FUNCTION fth_3V(Vth,V)
	REAL(rp), DIMENSION(3), INTENT(IN) :: V
    REAL(rp), INTENT(IN) :: Vth
	REAL(rp) :: fth_3V

    fth_3V = EXP(-0.5_rp*DOT_PRODUCT(V,V)/Vth**2.0_rp)
END FUNCTION fth_3V


FUNCTION fth_1V(Vth,V)
	REAL(rp), INTENT(IN) :: V
    REAL(rp), INTENT(IN) :: Vth
	REAL(rp) :: fth_1V

    fth_1V = EXP(-0.5_rp*(V/Vth)**2)
END FUNCTION fth_1V


FUNCTION random_norm(mean,sigma)
	REAL(rp), INTENT(IN) :: mean
	REAL(rp), INTENT(IN) :: sigma
	REAL(rp) :: random_norm
	REAL(rp) :: rand1, rand2

	call RANDOM_NUMBER(rand1)
	call RANDOM_NUMBER(rand2)

	random_norm = SQRT(-2.0_rp*LOG(1.0_rp-rand1))*COS(2.0_rp*C_PI*rand2);
END FUNCTION random_norm


subroutine thermal_distribution(params,spp)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(SPECIES), INTENT(INOUT) :: spp
    REAL(rp) :: Vmax,Vth, sv
    REAL(rp) :: ratio, rand_unif
    REAL(rp), DIMENSION(3) :: V, U
    REAL(rp), DIMENSION(3) :: b = (/1.0_rp,0.0_rp,0.0_rp/)
	INTEGER :: ii,ppp

	Vmax = 0.9_rp
    Vth = SQRT(spp%Eo*ABS(spp%q)/spp%m)
    ppp = spp%ppp

    V = (/0.0_rp,0.0_rp,0.0_rp/)
    sv = Vth/10.0_rp

    ii=2_idef
	do while (ii .LE. 1000_idef)
		U(1) = V(1) + random_norm(0.0_rp,sv)
		do while (ABS(U(1)) .GT. Vmax)
			U(1) = V(1) + random_norm(0.0_rp,sv)
		end do
		U(2) = V(2) + random_norm(0.0_rp,sv)
		do while (ABS(U(2)) .GT. Vmax)
			U(2) = V(2) + random_norm(0.0_rp,sv)
		end do
		U(3) = V(3) + random_norm(0.0_rp,sv)
		do while (ABS(U(3)) .GT. Vmax)
			U(3) = V(3) + random_norm(0.0_rp,sv)
		end do

		ratio = fth_3V(Vth,U)/fth_3V(Vth,V)

		if (ratio .GE. 1.0_rp) then
			V = U
			ii = ii + 1_idef
		else 
			call RANDOM_NUMBER(rand_unif)
			if (ratio .GT. rand_unif) then
				V = U
				ii = ii + 1_idef
			end if
		end if
	end do	

    spp%vars%V(:,1) = V
    ii=2_idef
	do while (ii .LE. ppp)
		U(1) = spp%vars%V(1,ii-1) + random_norm(0.0_rp,sv)
		do while (ABS(U(1)) .GT. Vmax)
			U(1) = spp%vars%V(1,ii-1) + random_norm(0.0_rp,sv)
		end do
		U(2) = spp%vars%V(2,ii-1) + random_norm(0.0_rp,sv)
		do while (ABS(U(2)) .GT. Vmax)
			U(2) = spp%vars%V(2,ii-1) + random_norm(0.0_rp,sv)
		end do
		U(3) = spp%vars%V(3,ii-1) + random_norm(0.0_rp,sv)
		do while (ABS(U(3)) .GT. Vmax)
			U(3) = spp%vars%V(3,ii-1) + random_norm(0.0_rp,sv)
		end do

		ratio = fth_3V(Vth,U)/fth_3V(Vth,spp%vars%V(:,ii-1))

		if (ratio .GE. 1.0_rp) then
			spp%vars%V(:,ii) = U
			ii = ii + 1_idef
		else 
			call RANDOM_NUMBER(rand_unif)
			if (ratio .GT. rand_unif) then
				spp%vars%V(:,ii) = U
				ii = ii + 1_idef
			end if
		end if
	end do

    do ii=1_idef,ppp
        spp%vars%g(ii) = 1.0_rp/SQRT(1.0_rp - SUM(spp%vars%V(:,ii)**2,1))
        spp%vars%eta(ii) = ACOS(DOT_PRODUCT(b,spp%vars%V(:,ii)/SQRT(SUM(spp%vars%V(:,ii)**2,1))))
    end do

	spp%go = spp%Eo/(spp%m*C_C**2)
	spp%etao = 90.0_rp
end subroutine thermal_distribution


subroutine initial_energy_pitch_dist(params,spp)
TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	INTEGER :: ii, mpierr ! Iterator

	do ii=1_idef,params%num_species
		SELECT CASE (TRIM(spp(ii)%energy_distribution))
			CASE ('MONOENERGETIC')
				spp(ii)%go = (spp(ii)%Eo + spp(ii)%m*C_C**2)/(spp(ii)%m*C_C**2)

				spp(ii)%vars%g = spp(ii)%go ! Monoenergetic
				spp(ii)%Eo_lims = (/spp(ii)%Eo, spp(ii)%Eo /)
			CASE ('THERMAL')
				call thermal_distribution(params,spp(ii))

				spp(ii)%Eo_lims = (/spp(ii)%m*C_C**2*MINVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2, &
									spp(ii)%m*C_C**2*MAXVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 /)
			CASE ('AVALANCHE')
				call get_avalanche_distribution(params,spp(ii)%vars%g,spp(ii)%vars%eta,spp(ii)%go,spp(ii)%etao)

				spp(ii)%Eo = spp(ii)%m*C_C**2*spp(ii)%go - spp(ii)%m*C_C**2
				spp(ii)%Eo_lims = (/spp(ii)%m*C_C**2*MINVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2, &
									spp(ii)%m*C_C**2*MAXVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 /)
			CASE ('HOLLMANN')
				call get_Hollmann_distribution(params,spp(ii)%vars%g,spp(ii)%vars%eta,spp(ii)%go,spp(ii)%etao)

				spp(ii)%Eo = spp(ii)%m*C_C**2*spp(ii)%go - spp(ii)%m*C_C**2
				spp(ii)%Eo_lims = (/spp(ii)%m*C_C**2*MINVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2, &
									spp(ii)%m*C_C**2*MAXVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 /)
			CASE ('EXPERIMENTAL-GAMMA')
				call get_experimentalG_distribution(params,spp(ii)%vars%g,spp(ii)%vars%eta,spp(ii)%go,spp(ii)%etao)

				spp(ii)%Eo = spp(ii)%m*C_C**2*spp(ii)%go - spp(ii)%m*C_C**2
				spp(ii)%Eo_lims = (/spp(ii)%m*C_C**2*MINVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2, &
									spp(ii)%m*C_C**2*MAXVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 /)
			CASE ('GAMMA')
				call get_gamma_distribution(params,spp(ii)%vars%g,spp(ii)%go)

				spp(ii)%Eo = spp(ii)%m*C_C**2*spp(ii)%go - spp(ii)%m*C_C**2
				spp(ii)%Eo_lims = (/spp(ii)%m*C_C**2*MINVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 , &
									spp(ii)%m*C_C**2*MAXVAL(spp(ii)%vars%g) - spp(ii)%m*C_C**2 /)
			CASE ('UNIFORM')
				spp(ii)%Eo = spp(ii)%Eo_lims(1)
				spp(ii)%go = (spp(ii)%Eo + spp(ii)%m*C_C**2)/(spp(ii)%m*C_C**2)

				call generate_2D_hammersley_sequence(params%mpi_params%rank,params%mpi_params%nmpi,spp(ii)%vars%g,spp(ii)%vars%eta)

				spp(ii)%vars%g = (spp(ii)%Eo_lims(2) - spp(ii)%Eo_lims(1))*spp(ii)%vars%g/(spp(ii)%m*C_C**2) + &
									(spp(ii)%Eo_lims(1) + spp(ii)%m*C_C**2)/(spp(ii)%m*C_C**2)
			CASE DEFAULT
				! Something to be done
		END SELECT

		call MPI_BARRIER(MPI_COMM_WORLD,mpierr)

		SELECT CASE (TRIM(spp(ii)%pitch_distribution))
			CASE ('MONOPITCH')
				spp(ii)%vars%eta = spp(ii)%etao ! Mono-pitch-angle
				spp(ii)%etao_lims = (/spp(ii)%etao , spp(ii)%etao/)
			CASE ('THERMAL')
				spp(ii)%etao_lims = (/MINVAL(spp(ii)%vars%eta), MAXVAL(spp(ii)%vars%eta)/)
			CASE ('AVALANCHE')
				spp(ii)%etao_lims = (/MINVAL(spp(ii)%vars%eta), MAXVAL(spp(ii)%vars%eta)/)
			CASE ('HOLLMANN')
				spp(ii)%etao_lims = (/MINVAL(spp(ii)%vars%eta), MAXVAL(spp(ii)%vars%eta)/)
			CASE ('EXPERIMENTAL-GAMMA')
				spp(ii)%etao_lims = (/MINVAL(spp(ii)%vars%eta), MAXVAL(spp(ii)%vars%eta)/)
			CASE ('UNIFORM')
				spp(ii)%etao = spp(ii)%etao_lims(1)

				spp(ii)%vars%eta = (spp(ii)%etao_lims(2) - spp(ii)%etao_lims(1))*spp(ii)%vars%eta + spp(ii)%etao_lims(1)
			CASE ('SIMPLE-EQUILIBRIUM')
				call get_equilibrium_distribution(params,spp(ii)%vars%eta,spp(ii)%go,spp(ii)%etao)

				spp(ii)%etao_lims = (/MINVAL(spp(ii)%vars%eta), MAXVAL(spp(ii)%vars%eta)/)
			CASE DEFAULT
				! Something to be done
		END SELECT

		if (params%mpi_params%rank .EQ. 0) then
			write(6,'(/,"* * * * * SPECIES: ",I2," * * * * * * * * * * *")') ii
			write(6,'("Energy distribution is: ",A20)') TRIM(spp(ii)%energy_distribution)
			write(6,'("Pitch-angle distribution is: ",A20)') TRIM(spp(ii)%pitch_distribution)
			write(6,'("* * * * * * * * * * * * * * * * * * * * * *",/)')
		end if

		call MPI_BARRIER(MPI_COMM_WORLD,mpierr)
	end do
end subroutine initial_energy_pitch_dist


subroutine gyro_distribution(params,F,spp)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(IN) :: F
	TYPE(SPECIES), INTENT(INOUT) :: spp
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Vo
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V1
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V2
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V3
	REAL(rp), DIMENSION(:,:), ALLOCATABLE :: b1, b2, b3
	REAL(rp), DIMENSION(:), ALLOCATABLE :: theta ! temporary vars
	REAL(rp), DIMENSION(3) :: x = (/1.0_rp,0.0_rp,0.0_rp/)
	REAL(rp), DIMENSION(3) :: y = (/0.0_rp,1.0_rp,0.0_rp/)
	REAL(rp), DIMENSION(3) :: z = (/0.0_rp,0.0_rp,1.0_rp/)
	INTEGER :: jj ! Iterator

	ALLOCATE( Vo(spp%ppp) )
	ALLOCATE( V1(spp%ppp) )
	ALLOCATE( V2(spp%ppp) )
	ALLOCATE( V3(spp%ppp) )
	ALLOCATE( b1(3,spp%ppp) )
	ALLOCATE( b2(3,spp%ppp) )
	ALLOCATE( b3(3,spp%ppp) )
		
	ALLOCATE( theta(spp%ppp) )

	! * * * * INITIALIZE VELOCITY * * * * 

	call init_random_seed()
	call RANDOM_NUMBER(theta)
	theta = 2.0_rp*C_PI*theta

	Vo = SQRT( 1.0_rp - 1.0_rp/(spp%vars%g(:)**2) )
	V1 = Vo*COS(C_PI*spp%vars%eta/180.0_rp)
	V2 = Vo*SIN(C_PI*spp%vars%eta/180.0_rp)*COS(theta)
	V3 = Vo*SIN(C_PI*spp%vars%eta/180.0_rp)*SIN(theta)

	call unitVectors(params,spp%vars%X,F,b1,b2,b3,spp%vars%flag)

	do jj=1_idef,spp%ppp
		if ( spp%vars%flag(jj) .EQ. 1_idef ) then
			spp%vars%V(1,jj) = V1(jj)*DOT_PRODUCT(b1(:,jj),x) + &
			                        V2(jj)*DOT_PRODUCT(b2(:,jj),x) + &
			                        V3(jj)*DOT_PRODUCT(b3(:,jj),x)

			spp%vars%V(2,jj) = V1(jj)*DOT_PRODUCT(b1(:,jj),y) + &
			                        V2(jj)*DOT_PRODUCT(b2(:,jj),y) + &
			                        V3(jj)*DOT_PRODUCT(b3(:,jj),y)

			spp%vars%V(3,jj) = V1(jj)*DOT_PRODUCT(b1(:,jj),z) + &
			                        V2(jj)*DOT_PRODUCT(b2(:,jj),z) + &
			                        V3(jj)*DOT_PRODUCT(b3(:,jj),z)
		end if
	end do

	DEALLOCATE(theta)
	DEALLOCATE(Vo)
	DEALLOCATE(V1)
	DEALLOCATE(V2)
	DEALLOCATE(V3)
	DEALLOCATE(b1)
	DEALLOCATE(b2)
	DEALLOCATE(b3)
end subroutine gyro_distribution


subroutine initial_velocity_distribution(params,F,spp)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(IN) :: F
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Vo
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V1
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V2
	REAL(rp), DIMENSION(:), ALLOCATABLE :: V3
	REAL(rp), DIMENSION(:,:), ALLOCATABLE :: b1, b2, b3
	REAL(rp), DIMENSION(:), ALLOCATABLE :: theta ! temporary vars
	REAL(rp), DIMENSION(3) :: x = (/1.0_rp,0.0_rp,0.0_rp/)
	REAL(rp), DIMENSION(3) :: y = (/0.0_rp,1.0_rp,0.0_rp/)
	REAL(rp), DIMENSION(3) :: z = (/0.0_rp,0.0_rp,1.0_rp/)
	INTEGER :: ss,jj ! Iterator

	do ss=1_idef,params%num_species
		SELECT CASE (TRIM(spp(ss)%energy_distribution))
			CASE ('THERMAL')
				!Nothing, all was done in initialize_particles through thermal_distribution
			CASE DEFAULT
				call gyro_distribution(params,F,spp(ss))
		END SELECT
	end do
end subroutine initial_velocity_distribution

END MODULE korc_velocity_distribution
