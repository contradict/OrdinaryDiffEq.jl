@inline function change_t_via_interpolation!{T}(integrator,t,modify_save_endpoint::Type{Val{T}}=Val{false})
  # Can get rid of an allocation here with a function
  # get_tmp_arr(integrator.cache) which gives a pointer to some
  # cache array which can be modified.
  if t < integrator.tprev
    error("Current interpolant only works between tprev and t")
  elseif t != integrator.t

    if typeof(integrator.u) <: AbstractArray
      integrator(integrator.u,t)
    else
      integrator.u = integrator(t)
    end
    integrator.t = t
    integrator.dt = integrator.t - integrator.tprev
    reeval_internals_due_to_modification!(integrator)
    if T
      solution_endpoint_match_cur_integrator!(integrator)
    end
  end
end

@inline function reeval_internals_due_to_modification!(integrator)
  if integrator.opts.calck
    resize!(integrator.k,integrator.kshortsize) # Reset k for next step!
    ode_addsteps!(integrator,integrator.f,Val{true},Val{false})
  end
  integrator.u_modified = false
end

@inline function u_modified!(integrator::ODEIntegrator,bool::Bool)
  integrator.u_modified = bool
end

user_cache(integrator::ODEIntegrator) = (integrator.cache.u,integrator.cache.uprev,integrator.cache.tmp)
u_cache(integrator::ODEIntegrator) = u_cache(integrator.cache)
du_cache(integrator::ODEIntegrator)= du_cache(integrator.cache)
full_cache(integrator::ODEIntegrator) = chain(user_cache(integrator),u_cache(integrator),du_cache(integrator.cache))
default_non_user_cache(integrator::ODEIntegrator) = chain(u_cache(integrator),du_cache(integrator.cache))
@inline add_tstop!(integrator::ODEIntegrator,t) = push!(integrator.opts.tstops,t)

resize!(integrator::ODEIntegrator,i::Int) = resize!(integrator,integrator.cache,i)
function resize!(integrator::ODEIntegrator,cache,i)
  for c in user_cache(integrator)
    resize!(c,i)
  end
  resize_non_user_cache!(integrator,cache,i)
end

resize_non_user_cache!(integrator::ODEIntegrator,i::Int) = resize_non_user_cache!(integrator,integrator.cache,i)

function resize_non_user_cache!(integrator::ODEIntegrator,cache,i)
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
end

function resize_non_user_cache!(integrator::ODEIntegrator,cache::Union{Rosenbrock23Cache,Rosenbrock32Cache},i)
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
  for c in vecu_cache(integrator.cache)
    resize!(c,i)
  end
  Jvec = vec(cache.J)
  cache.J = reshape(resize!(Jvec,i*i),i,i)
  Wvec = vec(cache.W)
  cache.W = reshape(resize!(Wvec,i*i),i,i)
end

function resize_non_user_cache!(integrator::ODEIntegrator,cache::Union{ImplicitEulerCache,TrapezoidCache},i)
  for c in default_non_user_cache(integrator)
    resize!(c,i)
  end
  for c in vecu_cache(integrator.cache)
    resize!(c,i)
  end
  for c in dual_cache(integrator.cache)
    resize!(c.du,i)
    resize!(c.dual_du,i)
  end
  if alg_autodiff(integrator.alg)
    cache.adf = autodiff_setup(cache.rhs,cache.uhold,integrator.alg)
  end
end

function resize_non_user_cache!(integrator::ODEIntegrator,cache::DiscreteCache,i)
  if discrete_scale_by_time(integrator.alg)
    for c in du_cache(integrator)
      resize!(c,i)
    end
  end
end

function deleteat!(integrator::ODEIntegrator,i::Int)
  for c in full_cache(integrator)
    deleteat!(c,i)
  end
end

function terminate!(integrator::ODEIntegrator)
  integrator.opts.tstops.valtree = typeof(integrator.opts.tstops.valtree)()
end
