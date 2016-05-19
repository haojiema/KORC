module korc_ppusher

    use korc_types
    use constants
    use korc_fields
    use korc_interp
    use korc_hpc

    implicit none

    PRIVATE :: cross
    PUBLIC :: advance_particles_position, advance_particles_velocity

    contains

function cross(a,b)
	REAL(rp), DIMENSION(3), INTENT(IN) :: a
	REAL(rp), DIMENSION(3), INTENT(IN) :: b
	REAL(rp), DIMENSION(3) :: cross

	cross(1) = a(2)*b(3) - a(3)*b(2)
	cross(2) = a(3)*b(1) - a(1)*b(3)
	cross(3) = a(1)*b(2) - a(2)*b(1)
end function cross


subroutine advance_particles_velocity(params,EB,spp,dt)
    implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(IN) :: EB
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	REAL(rp), INTENT(IN) :: dt
	REAL(rp) :: a, gammap, sigma, us, gamma, s ! variables of leapfrog of Vay, J.-L. PoP (2008)
	REAL(rp), DIMENSION(3) :: U, tau, up, t ! variables of leapfrog of Vay, J.-L. PoP (2008)
	REAL(rp) :: gamma_hs
	REAL(rp), DIMENSION(3) :: U_hs, V_hs
	REAL(rp), DIMENSION(3) :: acc, dacc, b_unit ! variables for diagnostics
	REAL(rp) :: B, vxa, vpar, vperp ! variables for diagnostics
	INTEGER :: ii, pp ! Iterators


	do ii = 1,params%num_species
		if (params%magnetic_field_model .EQ. 'ANALYTICAL') then
			call interp_analytical_field(spp(ii)%vars, EB)
		else
			call interp_field(spp(ii)%vars, EB)
		end if

	a = spp(ii)%q*dt/spp(ii)%m

!$OMP PARALLEL FIRSTPRIVATE(a,dt)&
!$OMP& PRIVATE(pp,U,U_hs,V_hs,gamma_hs,tau,up,gammap,sigma,us,gamma,t,s,&
!$OMP& acc,dacc,b_unit,B,vpar,vperp,vxa)&
!$OMP& SHARED(ii,spp)
!$OMP DO
		do pp=1,spp(ii)%ppp
			U = spp(ii)%vars%gamma(pp)*spp(ii)%vars%V(:,pp)
			U_hs = U + &
					0.5_rp*a*( spp(ii)%vars%E(:,pp) + cross(spp(ii)%vars%V(:,pp),spp(ii)%vars%B(:,pp)) )
            
			tau = 0.5_rp*dt*spp(ii)%q*spp(ii)%vars%B(:,pp)/spp(ii)%m
			up = U_hs + 0.5_rp*a*spp(ii)%vars%E(:,pp)
			gammap = sqrt( 1.0_rp + sum(up**2) )
			sigma = gammap**2 - sum(tau**2)
			us = sum(up*tau) ! variable 'u^*' in Vay, J.-L. PoP (2008)
			gamma = sqrt( 0.5_rp*(sigma + sqrt( sigma**2 + 4.0_rp*(sum(tau**2) + us**2) )) )
			t = tau/gamma
			s = 1.0_rp/(1.0_rp + sum(t**2)) ! variable 's' in Vay, J.-L. PoP (2008)

            U = s*( up + sum(up*t)*t + cross(up,t) )
            spp(ii)%vars%V(:,pp) = U/gamma

			spp(ii)%vars%gamma(pp) = gamma

!			write(6,'("Debuggin list:")') 
!			write(6,*) spp(ii)%q

			! Temporary quantities at half time step
			gamma_hs = sqrt( 1.0_rp + sum(U_hs**2) )
			V_hs = U_hs/gamma_hs

			! Instantaneous guiding center
			spp(ii)%vars%Rgc(:,pp) = spp(ii)%vars%X(:,pp)&
			+ gamma*spp(ii)%m*cross(V_hs, spp(ii)%vars%B(:,pp))&
			/( spp(ii)%q*sum(spp(ii)%vars%B(:,pp)**2) )
        
			B = sqrt( sum(spp(ii)%vars%B(:,pp)**2) )
			b_unit = spp(ii)%vars%B(:,pp)/B
			vpar = DOT_PRODUCT(spp(ii)%vars%V(:,pp), b_unit)
			vperp = sqrt( DOT_PRODUCT(spp(ii)%vars%V(:,pp),spp(ii)%vars%V(:,pp)) - vpar**2 )
            spp(ii)%vars%eta(pp) = 180.0_rp*modulo(atan2(vperp,vpar), 2.0_rp*C_PI)/C_PI
			spp(ii)%vars%mu(pp) = 0.5_rp*gamma*spp(ii)%m*vperp**2/B

			! Curvature and torsion
			acc = ( spp(ii)%q/spp(ii)%m )*cross(V_hs,spp(ii)%vars%B(:,pp))/gamma_hs
			vxa = sum( cross(V_hs,acc)**2 )
			spp(ii)%vars%kappa(pp) = sqrt( vxa )/( sqrt( sum(V_hs**2) )**3 )
			dacc = ( spp(ii)%q/spp(ii)%m )*cross(acc,spp(ii)%vars%B(:,pp))/gamma_hs
			spp(ii)%vars%tau(pp) = DOT_PRODUCT(V_hs,cross(acc, dacc))/vxa

		end do
!$OMP END DO
!$OMP END PARALLEL

	end do
end subroutine advance_particles_velocity


subroutine advance_particles_position(params,EB,spp,dt)
    implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(IN) :: EB
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
	REAL(rp), INTENT(IN) :: dt
	INTEGER :: ii, pp ! Iterators

    do ii = 1,params%num_species
!$OMP PARALLEL PRIVATE(pp) SHARED(ii,spp,dt,params)
!$OMP DO
	do pp = 1,spp(ii)%ppp
		spp(ii)%vars%X(:,pp) = spp(ii)%vars%X(:,pp) + dt*spp(ii)%vars%V(:,pp)
	end do
!$OMP END DO
!$OMP END PARALLEL
	end do
end subroutine advance_particles_position

end module korc_ppusher