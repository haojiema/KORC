MODULE korc_experimental_pdf
	USE korc_types
	USE korc_constants
	USE korc_HDF5
	USE korc_hpc
    USE special_functions

	IMPLICIT NONE

	TYPE, PRIVATE :: PARAMS
		REAL(rp) :: E ! Parallel electric field normalized using the critical electric field
		REAL(rp) :: Zeff ! Effective atomic number of impurities

		REAL(rp) :: max_pitch_angle ! Maximum pitch angle of sampled PDF in degrees
		REAL(rp) :: min_pitch_angle ! Minimum pitch angle of sampled PDF in degrees
		REAL(rp) :: min_energy ! Minimum energy of sampled PDF in MeV
		REAL(rp) :: max_energy ! Maximum energy of sampled PDF in MeV
		REAL(rp) :: min_p ! Minimum momentum of sampled PDF
		REAL(rp) :: max_p ! Maximum momentum of sampled PDF
		REAL(rp) :: k ! Shape factor of Gamma distribution
		REAL(rp) :: t ! Scale factor of Gamma distribution

		REAL(rp) :: Bo
		REAL(rp) :: lambda
	END TYPE PARAMS

	TYPE(PARAMS), PRIVATE :: pdf_params
	REAL(rp), PRIVATE, PARAMETER :: xo = (C_ME*C_C**2/C_E)/1.0E6
	REAL(rp), PRIVATE, PARAMETER :: Tol = 1.0E-5_rp

	PUBLIC :: get_experimental_distribution
	PRIVATE :: initialize_params,&
				save_params,&
				sample_distribution,&
				deg2rad,&
				fRE,&
				random_norm,&
				fGamma,&
				PR,&
				P_integral,&
				IntK,&
				nintegral_besselk

	CONTAINS

SUBROUTINE get_experimental_distribution(params,g,eta,go,etao)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: g
	REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: eta
	REAL(rp), INTENT(OUT) :: go
	REAL(rp), INTENT(OUT) :: etao

	call initialize_params(params)

	call save_params(params)

	call sample_distribution(params,g,eta,go,etao)

END SUBROUTINE get_experimental_distribution


SUBROUTINE initialize_params(params)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	REAL(rp) :: max_pitch_angle
	REAL(rp) :: min_pitch_angle
	REAL(rp) :: max_energy
	REAL(rp) :: min_energy
	REAL(rp) :: Zeff
	REAL(rp) :: E
	REAL(rp) :: k
	REAL(rp) :: t
	REAL(rp) :: Bo
	REAL(rp) :: lambda
	NAMELIST /ExperimentalPDF/ max_pitch_angle,min_pitch_angle,max_energy,min_energy,Zeff,E,k,t,Bo,lambda

	open(unit=default_unit_open,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
	read(default_unit_open,nml=ExperimentalPDF)
	close(default_unit_open)

	pdf_params%max_pitch_angle = max_pitch_angle
	pdf_params%min_pitch_angle = min_pitch_angle
	pdf_params%min_energy = min_energy*C_E ! In Joules	
	pdf_params%max_energy = max_energy*C_E ! In Joules
	pdf_params%Zeff = Zeff
	pdf_params%E = E
	pdf_params%k = k
	pdf_params%t = t
	pdf_params%Bo = Bo
	pdf_params%lambda = lambda

	pdf_params%max_p = SQRT((pdf_params%max_energy/(C_ME*C_C**2))**2 - 1.0_rp) ! In units of mc
	pdf_params%min_p = SQRT((pdf_params%min_energy/(C_ME*C_C**2))**2 - 1.0_rp) ! In units of mc
END SUBROUTINE initialize_params


FUNCTION deg2rad(x)
	REAL(rp), INTENT(IN) :: x
	REAL(rp) :: deg2rad
	
	deg2rad = C_PI*x/180.0_rp
END FUNCTION


FUNCTION fGamma(x,k,t)
	REAL(rp), INTENT(IN) :: x ! Independent variable
	REAL(rp), INTENT(IN) :: k ! Shape factor
	REAL(rp), INTENT(IN) :: t ! Scale factor
	REAL(rp) :: fGamma

	fGamma = x**(k - 1.0_rp)*EXP(-x/t)/(GAMMA(k)*t**k)
END FUNCTION fGamma


FUNCTION fRE(eta,p)
	REAL(rp), INTENT(IN) :: eta ! pitch angle in degrees
	REAL(rp), INTENT(IN) :: p ! momentum in units of mc
	REAL(rp) :: fRE
	REAL(rp) :: A
	REAL(rp) :: Eo

	Eo = SQRT(p**2.0_rp + 1.0_rp)

	A = (2.0_rp*pdf_params%E/(pdf_params%Zeff + 1.0_rp))*(p**2/SQRT(p**2.0_rp + 1.0_rp))
	fRE = 0.5_rp*A*EXP(A*COS(deg2rad(eta)))*fGamma(Eo,pdf_params%k,pdf_params%t/xo)/SINH(A)
	fRE = fRE*PR(eta,p)
END FUNCTION fRE


FUNCTION random_norm(mean,sigma)
	REAL(rp), INTENT(IN) :: mean
	REAL(rp), INTENT(IN) :: sigma
	REAL(rp) :: random_norm
	REAL(rp) :: rand1, rand2

	call RANDOM_NUMBER(rand1)
	call RANDOM_NUMBER(rand2)

	random_norm = SQRT(-2.0_rp*LOG(1.0_rp-rand1))*COS(2.0_rp*C_PI*rand2);
END FUNCTION random_norm


FUNCTION IntK(v,x)
	IMPLICIT NONE
	REAL(rp) :: IntK
	REAL(rp), INTENT(IN) :: v
	REAL(rp), INTENT(IN) :: x

	IntK = (C_PI/SQRT(2.0_rp))*(1.0_rp - 0.25_rp*(4.0_rp*v**2 - 1.0_rp))*ERFC(SQRT(x))&
			 + 0.25_rp*(4.0_rp*v**2 - 1.0_rp)*SQRT(0.5_rp*C_PI/x)*EXP(-x)
END FUNCTION IntK

FUNCTION besselk(v,x)
	IMPLICIT NONE
	REAL(rp) :: besselk
	REAL(rp), INTENT(IN) :: x
	REAL(rp), INTENT(IN) :: v
	REAL(4) :: ri,rk,rip,rkp

	call bessik(REAL(x,4),REAL(v,4),ri,rk,rip,rkp)
	besselk = REAL(rk,rp)
END FUNCTION besselk

FUNCTION nintegral_besselk(a,b)
	IMPLICIT NONE
	REAL(rp), INTENT(IN) :: a
	REAL(rp), INTENT(IN) :: b
	REAL(rp) :: nintegral_besselk
	REAL(rp) :: Iold, Inew, rerr
	REAL(rp) :: v,h,z
	INTEGER :: ii,jj,npoints
	LOGICAL :: flag
	
	v = 5.0_rp/3.0_rp

	h = b - a
	nintegral_besselk = 0.5*(besselk(v,a) + besselk(v,b))
	
	ii = 1_idef
	flag = .TRUE.
	do while (flag)
		Iold = nintegral_besselk*h

		ii = ii + 1_idef
		npoints = 2_idef**(ii-2_idef)
		h = 0.5_rp*(b-a)/REAL(npoints,rp)

		do jj=1_idef,npoints
			z = a + h + 2.0_rp*(REAL(jj,rp) - 1.0_rp)*h
			nintegral_besselk = nintegral_besselk + besselk(v,z)
		end do

		Inew = nintegral_besselk*h

		rerr = ABS((Inew - Iold)/Iold)

		flag = .NOT.(rerr.LT.Tol)
	end do
	nintegral_besselk = Inew
END FUNCTION nintegral_besselk

SUBROUTINE P_integral(z,P)
	REAL(rp), INTENT(OUT) :: P
	REAL(rp), INTENT(IN) :: z
	REAL(rp) :: a

	P = 0.0_rp

	IF (z .LT. 0.5_rp) THEN
		a = (2.16_rp/2.0_rp**(2.0_rp/3.0_rp))*z**(1.0_rp/3.0_rp)
		P = nintegral_besselk(z,a) + IntK(5.0_rp/3.0_rp,a)
	ELSE IF ((z .GE. 0.5_rp).AND.(z .LT. 2.5_rp)) THEN
		a = 0.72_rp*(z + 1.0_rp)
		P = nintegral_besselk(z,a) + IntK(5.0_rp/3.0_rp,a)
	ELSE
		P = IntK(5.0_rp/3.0_rp,z)
	END IF
END SUBROUTINE P_integral


FUNCTION PR(eta,p)
	REAL(rp), INTENT(IN) :: eta ! in radians
	REAL(rp), INTENT(IN) :: p ! dimensionless (in units of mc)
	REAL(rp) :: PR
	REAL(rp) :: g
	REAL(rp) :: v
	REAL(rp) :: k
	REAL(rp) :: l,lc
	REAL(rp) :: z
	REAL(rp) :: Pi

	g = SQRT(p**2 + 1.0_rp)
	v = C_C*SQRT(1.0_rp - 1.0_rp/g**2)

	k = C_E*pdf_params%Bo*SIN(deg2rad(eta))/(g*C_ME*v)

	l = pdf_params%lambda
	lc = (4.0_rp*C_PI/3.0_rp)/(k*g**3) ! Critical wavelength

	z = lc/l

	call P_integral(z,Pi)

	PR = (C_C*C_E**2)*Pi/(SQRT(3.0_rp)*C_E0*g**2*l**3)
END FUNCTION PR


SUBROUTINE sample_distribution(params,g,eta,go,etao)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: g
	REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: eta
	REAL(rp), INTENT(OUT) :: go
	REAL(rp), INTENT(OUT) :: etao
	REAL(rp) :: go_root
	REAL(rp) :: etao_root
	REAL(rp), DIMENSION(:), ALLOCATABLE :: p
	REAL(rp) :: p_buffer, p_test
	REAL(rp) :: eta_buffer, eta_test
	REAL(rp) :: ratio, rand_unif
	REAL(rp), DIMENSION(:), ALLOCATABLE :: p_samples
	REAL(rp), DIMENSION(:), ALLOCATABLE :: eta_samples
	REAL(rp) :: deta
	REAL(rp) :: dp
	INTEGER :: ii,ppp,nsamples
	INTEGER :: mpierr

	ppp = SIZE(g)
	nsamples = ppp*params%mpi_params%nmpi
	ALLOCATE(p(ppp))

	deta = pdf_params%max_pitch_angle/50.0_rp
	dp = 1.0_rp

	if (params%mpi_params%rank.EQ.0_idef) then
		ALLOCATE(p_samples(nsamples))! Number of samples to distribute among all MPI processes
		ALLOCATE(eta_samples(nsamples))! Number of samples to distribute among all MPI processes

		call RANDOM_SEED()
		call RANDOM_NUMBER(rand_unif)
		eta_buffer = pdf_params%min_pitch_angle + (pdf_params%max_pitch_angle - pdf_params%min_pitch_angle)*rand_unif
		call RANDOM_NUMBER(rand_unif)
		p_buffer = pdf_params%min_p + (pdf_params%max_p - pdf_params%min_p)*rand_unif

		ii=2_idef
		do while (ii .LE. 1000000_idef)
			eta_test = eta_buffer + random_norm(0.0_rp,deta)
			do while ((ABS(eta_test) .GT. pdf_params%max_pitch_angle).OR.(ABS(eta_test) .LT. pdf_params%min_pitch_angle))
				eta_test = eta_buffer + random_norm(0.0_rp,deta)
			end do

			p_test = p_buffer + random_norm(0.0_rp,dp)
			do while ((p_test.LT.pdf_params%min_p).OR.(p_test.GT.pdf_params%max_p))
				p_test = p_buffer + random_norm(0.0_rp,dp)
			end do

			ratio = fRE(eta_test,p_test)/fRE(eta_buffer,p_buffer)

			if (ratio .GE. 1.0_rp) then
				p_buffer = p_test
				eta_buffer = eta_test
				ii = ii + 1_idef
			else 
				call RANDOM_NUMBER(rand_unif)
				if (rand_unif .LT. ratio) then
					p_buffer = p_test
					eta_buffer = eta_test
					ii = ii + 1_idef
				end if
			end if
		end do	

		eta_samples(1) = eta_buffer
		call RANDOM_SEED()
		call RANDOM_NUMBER(rand_unif)
		p_samples(1) = p_buffer

		ii=2_idef
		do while (ii .LE. nsamples)
			eta_test = eta_samples(ii-1) + random_norm(0.0_rp,deta)
			do while ((ABS(eta_test) .GT. pdf_params%max_pitch_angle).OR.(ABS(eta_test) .LT. pdf_params%min_pitch_angle))
				eta_test = eta_samples(ii-1) + random_norm(0.0_rp,deta)
			end do

			p_test = p_samples(ii-1) + random_norm(0.0_rp,dp)
			do while ((p_test.LT.pdf_params%min_p).OR.(p_test.GT.pdf_params%max_p))
				p_test = p_samples(ii-1) + random_norm(0.0_rp,dp)
			end do

			ratio = fRE(eta_test,p_test)/fRE(eta_samples(ii-1),p_samples(ii-1))

			if (ratio .GE. 1.0_rp) then
				p_samples(ii) = p_test
				eta_samples(ii) = eta_test
				ii = ii + 1_idef
			else 
				call RANDOM_NUMBER(rand_unif)
				if (rand_unif .LT. ratio) then
					p_samples(ii) = p_test
					eta_samples(ii) = eta_test
					ii = ii + 1_idef
				end if
			end if
		end do	
	
		eta_samples = ABS(eta_samples)

		go = SUM(SQRT(1.0_rp + p_samples**2))/nsamples
		etao = SUM(eta_samples)/nsamples
	end if

	CALL MPI_SCATTER(p_samples,ppp,MPI_REAL8,p,ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

	CALL MPI_SCATTER(eta_samples,ppp,MPI_REAL8,eta,ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

	CALL MPI_BCAST(go,1,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
	
	CALL MPI_BCAST(etao,1,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

	call MPI_BARRIER(MPI_COMM_WORLD,mpierr)

	g = SQRT(1.0_rp + p**2)

	DEALLOCATE(p)
	if (params%mpi_params%rank.EQ.0_idef) then
		DEALLOCATE(p_samples)
		DEALLOCATE(eta_samples)
	end if

END SUBROUTINE sample_distribution


SUBROUTINE save_params(params)
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	CHARACTER(MAX_STRING_LENGTH) :: filename
	CHARACTER(MAX_STRING_LENGTH) :: gname
	CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
	CHARACTER(MAX_STRING_LENGTH) :: dset
	CHARACTER(MAX_STRING_LENGTH) :: attr
	INTEGER(HID_T) :: h5file_id
	INTEGER(HID_T) :: group_id
	INTEGER :: h5error
	REAL(rp) :: units

	if (params%mpi_params%rank .EQ. 0) then
		filename = TRIM(params%path_to_outputs) // "experimental_distribution_parameters.h5"
		call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)

		gname = "params"
		call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

		dset = TRIM(gname) // "/max_pitch_angle"
		attr = "Maximum pitch angle in avalanche PDF (degrees)"
		call save_to_hdf5(h5file_id,dset,pdf_params%max_pitch_angle,attr)

		dset = TRIM(gname) // "/min_pitch_angle"
		attr = "Minimum pitch angle in avalanche PDF (degrees)"
		call save_to_hdf5(h5file_id,dset,pdf_params%min_pitch_angle,attr)

		dset = TRIM(gname) // "/min_energy"
		attr = "Minimum energy in avalanche PDF (eV)"
		units = 1.0_rp/C_E
		call save_to_hdf5(h5file_id,dset,units*pdf_params%min_energy,attr)

		dset = TRIM(gname) // "/max_energy"
		attr = "Maximum energy in avalanche PDF (eV)"
		units = 1.0_rp/C_E
		call save_to_hdf5(h5file_id,dset,units*pdf_params%max_energy,attr)

		dset = TRIM(gname) // "/max_p"
		attr = "Maximum momentum in avalanche PDF (me*c^2)"
		call save_to_hdf5(h5file_id,dset,pdf_params%max_p,attr)

		dset = TRIM(gname) // "/min_p"
		attr = "Maximum momentum in avalanche PDF (me*c^2)"
		call save_to_hdf5(h5file_id,dset,pdf_params%min_p,attr)

		dset = TRIM(gname) // "/Zeff"
		attr = "Effective atomic number of ions."
		call save_to_hdf5(h5file_id,dset,pdf_params%Zeff,attr)

		dset = TRIM(gname) // "/E"
		attr = "Parallel electric field in (Ec)"
		call save_to_hdf5(h5file_id,dset,pdf_params%E,attr)

		dset = TRIM(gname) // "/k"
		attr = "Shape factor"
		call save_to_hdf5(h5file_id,dset,pdf_params%k,attr)

		dset = TRIM(gname) // "/t"
		attr = "Scale factor"
		call save_to_hdf5(h5file_id,dset,pdf_params%t,attr)

		call h5gclose_f(group_id, h5error)

		call h5fclose_f(h5file_id, h5error)
	end if
END SUBROUTINE save_params

END MODULE korc_experimental_pdf
