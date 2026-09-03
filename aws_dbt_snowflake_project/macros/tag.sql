{% macro tag(col_name) %}
    CASE
        WHEN {{col_name}} < 100 THEN 'low'
        WHEN {{col_name}} < 200 THEN 'medium'
        ELSE 'high'
    END
{% endmacro %}