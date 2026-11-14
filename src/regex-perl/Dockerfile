# Container image for the Perl regex entry. Run it with: sandbox/container/run-image.sh src/regex-perl
# Perl and its standard modules ship in the Ubuntu base; the base adds sqlite3 only.
FROM cc-rt-sqlite:local
COPY timecards.pl /app/timecards.pl
ENV CC_RUN="perl /app/timecards.pl"
