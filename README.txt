ee.values.sh - compute the values of EE Savings Bonds over time

By default compute the value as of the current month.  Optionally, with the
flag -a, compute values from the issuing month to the current month.

ee.values.sh [-a] <holdings>

Where <holdings> is a file containing lines in the format Series, Issue date,
Serial Number, and Face value.  For example:

EE 1990-07-01 C123019924EE 100.00
