create extension if not exists pg_trgm;

create or replace function public.search_suggestions(
    search_query text,
    max_results int default 5
)
returns table(
    suggestion_type text,
    suggestion_text text,
    suggestion_id uuid
)
language sql
stable
as $$
    with normalized as (
        select nullif(trim(search_query), '') as q
    )
    select *
    from (
        select
            'brand'::text as suggestion_type,
            brand_matches.name as suggestion_text,
            null::uuid as suggestion_id
        from (
            select distinct b.name
            from public.brands b
            cross join normalized n
            where n.q is not null
              and b.name ilike n.q || '%'
            order by b.name
            limit max_results
        ) brand_matches
    ) brand_suggestions

    union all

    select *
    from (
        select
            'note'::text as suggestion_type,
            note_matches.name as suggestion_text,
            null::uuid as suggestion_id
        from (
            select distinct nte.name
            from public.notes nte
            cross join normalized n
            where n.q is not null
              and nte.name ilike n.q || '%'
            order by nte.name
            limit max_results
        ) note_matches
    ) note_suggestions

    union all

    select *
    from (
        select
            'perfume'::text as suggestion_type,
            p.name as suggestion_text,
            p.id as suggestion_id
        from public.perfumes p
        cross join normalized n
        where n.q is not null
          and p.name ilike '%' || n.q || '%'
        order by p.name
        limit max_results
    ) perfume_suggestions;
$$;

create index if not exists idx_brands_name_trgm
    on public.brands using gin (name gin_trgm_ops);

create index if not exists idx_notes_name_trgm
    on public.notes using gin (name gin_trgm_ops);

create index if not exists idx_perfumes_name_trgm
    on public.perfumes using gin (name gin_trgm_ops);
