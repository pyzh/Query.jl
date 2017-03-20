@require TypedTables begin

immutable TypedTableIterator{T, TS}
    df::TypedTables.Table
    # This field hols a tuple with the columns of the DataFrame.
    # Having a tuple of the columns here allows the iterator
    # functions to access the columns in a type stable way.
    columns::TS
end

@traitimpl IsIterable{TypedTables.Table}
@traitimpl IsIterableTable{TypedTables.Table}

function getiterator(df::TypedTables.Table)
    col_expressions = Array{Expr,1}()
    df_columns_tuple_type = Expr(:curly, :Tuple)
    for i in 1:length(df.data)
        etype = eltype(df.data[i])
        push!(col_expressions, Expr(:(::), names(df)[i], etype <: Nullable ? DataValue{etype.parameters[1]} : etype))
        push!(df_columns_tuple_type.args, typeof(df.data[i]))
    end
    t_expr = NamedTuples.make_tuple(col_expressions)

    t2 = :(Query.TypedTableIterator{Float64,Float64})
    t2.args[2] = t_expr
    t2.args[3] = df_columns_tuple_type

    eval(NamedTuples, :(import Query))
    t = eval(NamedTuples, t2)

    e_df = t(df, df.data)

    return e_df
end

function length{T,TS}(iter::TypedTableIterator{T,TS})
    return size(iter.df,1)
end

function eltype{T,TS}(iter::TypedTableIterator{T,TS})
    return T
end

function start{T,TS}(iter::TypedTableIterator{T,TS})
    return 1
end

@generated function next{T,TS}(iter::TypedTableIterator{T,TS}, state)
    constructor_call = Expr(:call, :($T))
    for (i,t) in enumerate(T.parameters)
        push!(constructor_call.args, t<:DataValue ? :(isnull(columns[$i][i]) ? DataValue{$(t.parameters[1])}() : DataValue{$(t.parameters[1])}(get(columns[$i][i]))) : :(columns[$i][i]))
    end

    quote
        i = state
        columns = iter.columns
        a = $constructor_call
        return a, state+1
    end
end

function done{T,TS}(iter::TypedTableIterator{T,TS}, state)
    return state>size(iter.df,1)
end

end
