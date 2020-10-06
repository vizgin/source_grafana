# Blendstat Panel

The Blendstat Panel is a third-party [Grafana](https://grafana.com/) visualization panel. It is nearly identical to the native [Singlestat](http://docs.grafana.org/features/panels/singlestat/), except it allows for multiple series or queries.

Values from different queries are combined (blended) into single series based on a user-selected function (e.g., `Average`, `Total`, etc) prior to the value for the panel being calculated. Values are blended when they share a timestamp.
