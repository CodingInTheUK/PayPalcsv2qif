# PayPalcsv2qif
A small program written in perl to convert PayPal CSV files to QIF format.

As this repository for to hold this program should I ever lose access to my own copy, I would be grateful to any perl programmer who feels they could make improvements to this program, conversions for UK banks would be great future addition.


# Dependencies
Perl for commandline

TEXT::CSV installed (linux)

You can get information on installing the TEXT::CSV on various linux distributions here: https://stackoverflow.com/a/26232844/2154871

Windows may have dependencies that I am unaware of, you should see some information when you try to convert if this is the case, please submit a git pull for this readme if that's the case.


# Prerequisite
Download your CSV File from paypal > reports > Activity downloads.
When preparing to download, select **Balance affecting and CSV** choose your timeframe.

You will also see Customise report fields, you should click this and **uncheck** the very last checkbox "include shopping cart items". LEaving this checked may make your imported data hard to manage.

Now you can create your report, once completed download the CSV into the **same directory as the converter**.

You will need to open your terminal and change the terminals working directory to the current location of csv2qif.pl

**cd path/to/csv2qif.pl**

Make the file/program executable to allow it to run from the terminal.
**chmod +x csv2qif.pl**

# Usage
**perl csv2qif.pl paypal.csv

Once complete you will be notified in the terminal, success or fail. Upon success your QIF file(s) will be located in the same directory as the converter ready for import into GNUCASH.


# Thanks
Thank to Lloyd Standish for creating this program and permitting the sharing/modifying.
