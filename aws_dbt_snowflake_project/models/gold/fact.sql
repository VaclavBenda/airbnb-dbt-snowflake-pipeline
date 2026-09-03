{% set configs = [
    {
        "table": "AIRBNB.GOLD.OBT",
        "columns": "obt.BOOKING_ID, obt.LISTING_ID, obt.HOST_ID, obt.TOTAL_AMOUNT, obt.ACCOMMODATES, obt.BEDROOMS, obt.BATHROOMS, obt.PRICE_PER_NIGHT, obt.RESPONSE_RATE"
    }
] %}

SELECT 
    {% for config in configs %}
        {{ config.columns }}{% if not loop.last%},{% endif %}
    {% endfor %}
FROM
    {{configs[0]['table']}}
