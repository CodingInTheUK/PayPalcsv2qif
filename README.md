# PayPalcsv2qif
A small program written in perl to convert PayPal CSV files to QIF format. Known to work in linux for GNUCASH

# Dependencies
Perl for commandline

TEXT::CSV installed


# Prerequisite
Download your CSV File from paypal > reports > Activity downloads.
When preparing to download, select **Balance affecting and CSV** choose your timeframe.

You will also see Customise report fields, you should click this and **uncheck** the very last checkbox "include shopping cart items". LEaving this checked may make your imported data hard to manage.

Now you can create your report, once completed download the CSV into the **same directory as the converter**.

You will need to open your terminal and change the terminals working directory to the current location of csv2qif.pl

**cd path/to/csv2qif.pl

**chmod +x csv2qif.pl

# Usage
**perl csv2qif.pl paypal.csv

Once complete you will be notified in the terminal, success or fail. Upon success your QIF file(s) will be located in the same directory as the converter ready for import into GNUCASH.
