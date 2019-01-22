#!/usr/bin/perl
#    Copyright 2012 Lloyd Standish
#    http://www.crnatural.net/PayPalcsv2qif
#    lloyd@crnatural.net

#    This script is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version. See <http://www.gnu.org/licenses/>.
#
#    This script is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

# had to install Text::CSV v1.33 to correct errors, hence the following line uncommented to pull in new version of library
use lib "/var/www/lloyd/cgi-bin";
use strict;
use charnames ':full';
no strict "refs";

# the following dependency will need to be installed from CPAN
# perl -MCPAN -e shell
# install Text::CSV
use Text::CSV;

sub return_fh {             # make anon filehandle
    local *FH;              # must be local, not my
    # now open it if you want to, then...
    return *FH;
}

my $version="2.24";
print "PayPal/BNCR CSV to QIF convertor version $version\n";

my $myppaccount="";
my $mychaseaccount="";
my $myBNCRaccount="";

# optional: adjust the following to your account names (USD only)
# or, comment out the following 3 lines to have gnucash import wizard prompt for the accounts.
#$myppaccount="Assets:Current Assets:PayPal GBP";
#$mychaseaccount="Assets:Current Assets:Checking Account";
#$myBNCRaccount="Activos:Activos Corrientes:BNCR cuenta corriente CRC";

# optional: enable shipping and handling split (beta). (Change 0 to 1 to enable)
my $shipsplit=1;

my $myaccount;
my $fh;

file: foreach my $sourcefile (@ARGV)
{
	my ($base,$ext) = split(/\./, lc($sourcefile));
	if ($ext ne "csv")
	{
		"$sourcefile is not a csv-extension file, skipping\n";
		next;
	}
	if (! -e $sourcefile)
	{
		"$sourcefile not found, skipping\n";
		next;
	}
#	if (-x flip)
#	{
#	  `flip -m $sourcefile`;
#	}

	if (!open(READ,$sourcefile))
	{
		print "Error: Could not open $sourcefile for reading.\n";
		next;
	}

	if (!open($fh,"+>:encoding(iso-8859-1)","$base.m.csv"))
	{
		print "Error: Could not open $base.m.csv for reading/writing.\n";
		next;
	}

	my $bom;
	read READ,$bom,3;
	if ($bom ne "\xEF\xBB\xBF") {
		seek (READ,0,0);
	}
	undef $/;
	$_=<READ>;
# convert unix line ending to dos
	$_ =~ s/\r?\n|\r/\r\n/g;
	print $fh $_;
	close READ;

	$/ = "\r\n";
	
	seek ($fh,0,0);

my $csv = Text::CSV->new ( { allow_whitespace => 1, binary => 1 } );  # should set binary attribute.
if (! $csv)
{
	print "Cannot use CSV: ".Text::CSV->error_diag ();
	exit 0;
}
#open my $fh, "<:encoding(iso-8859-1)", "test.csv" or die "test.csv: $!";
my @requirednames;
my $source;

if (lc($sourcefile) =~ /jpmc/)
{
	@requirednames=("Post Date","Description","Amount");
	$myaccount=$mychaseaccount;
	$source="jpmc";
}
elsif (lc($sourcefile) =~ /bncr/)
{
	@requirednames=("fechaMovimiento","descripcion","credito","debito");
	$myaccount=$myBNCRaccount;
	$source="bncr";
	$csv->sep_char(";");
}
else
{
	@requirednames=("Date","Net","Type","Gross","Fee","Name","Status");
	$myaccount=$myppaccount;
	$source="paypal";
}
my $row=$csv->getline ($fh);
my @fields = @$row;
my $chasenoheader=0;
required: foreach my $requiredname (@requirednames)
{
    for (my $i=0; $i<scalar(@fields); $i++)
    {
      $fields[$i] =~ s/^\s*//; # remove leading space
      $fields[$i] =~ s/\s*$//; # remove trailing space
      $fields[$i] =~ s/"//g; # remove double quotes, latest change in PayPal
      if ($fields[$i] eq $requiredname)
      {
#	print "found $requiredname\n";
	next required;
      }
      elsif ($fields[$i] =~ /\d/ and $source eq "jpmc")
      {
	    $chasenoheader=1;
      }
    }
    if (!$chasenoheader)
    {
	print "missing required field $requiredname, skipping file $sourcefile\n";
	close $fh;
#	unlink "${base}.m.csv";
	next file;
    }
}

if ($chasenoheader)
{
# old style file, fype field is not used
	$csv->column_names ("Type","Post Date","Description","Amount");
	seek ($fh,0,0);
}
else
{
	$csv->column_names (@fields);
#	$csv->column_names ($row);
}

# here we need to determine currencies and open a separate qif file for each currency
# filehandle for each qif file is its currency name
my %handles;
curcheck: while ( $row = $csv->getline_hr( $fh ) ) {
	my $currency=$row->{'Currency'};
	if (!$currency)
	{
		if ($source eq "bncr")
		{
		    $currency='CRC';
		}
		else
		{
		    $currency='USD';
		}
	}
	if (exists $handles{$currency}) {
		next curcheck;
	}
	$handles{$currency}=return_fh();
	if (!open($handles{$currency},">:encoding(iso-8859-1)","$base-$currency.qif"))
	{
		print "Error: Could not open $base-$currency.qif for writing.\n";
		next file;
	}
}
seek ($fh,0,0);
$row = $csv->getline ($fh);
#$row =~ s/[\x80-\xFF]//g;
if ($myaccount and exists $handles{'USD'})
{
	print {$handles{'USD'}} "!Account\r\n";
	print {$handles{'USD'}} "N$myaccount\r\n";
	print {$handles{'USD'}} "TCash\r\n";
	print {$handles{'USD'}} "^\r\n";
}

#'General Currency Conversion'
#'General Withdrawal'
#'Payment Refund'
#'General Payment'

my %types = (
	'Coupon Redemption' => 'Coupon Redemption',
	'Donation Payment' => 'Donation Payment',
 	'eBay Auction Payment' => 'eBay Auction Payment',
	'Mobile Payment' => 'Mobile Payment',
	'PreApproved Payment Bill User Payment' => 'PreApproved Payment Bill User Payment',
	'Account Hold for Open Authorization' => 'Temporary Hold',
	'Account Hold for Open Authorisation' => 'Temporary Hold',
	'General Authorization' => 'Authorization',
	'General Authorisation' => 'Authorization',
	'Cancellation of Hold for Dispute Resolution' =>'Temporary Hold',
	'Hold on Balance for Dispute Investigation' => 'Temporary Hold',
	'Mass Pay Payment' => 'Temporary Hold',
	'Reversal of General Account Hold' => 'Temporary Hold',
	'General Currency Conversion' => 'Currency Conversion',
	'General Withdrawal' => 'Withdrawal',
	'Payment Refund' => 'Payment Refund',
	'General Payment' => 'General Payment'
);
my $refund_trans="";
	
while ( $row = $csv->getline_hr( $fh ) ) {

# print "Price for $hr->{name} is $hr->{price} EUR\n";
#     $row->[2] =~ m/pattern/ or next; # 3rd field should match
#     push @rows, $row;
		my $mytype;
		my $type;
		my $date;
		my $net;
		my $gross;
		my $currency;
		my $itemtitle="";
		my $taxliability="";
		my $shiphandling="";
		if ($source eq "jpmc")
		{
			$date=$row->{'Post Date'};
			$type=$row->{'Description'};
			$net=$row->{'Amount'};
			$gross=$row->{'Amount'};
			$mytype=$type;
			$currency="USD";
		}
		elsif ($source eq "bncr")
		{
			$date=$row->{'fechaMovimiento'};
			$type=$row->{'descripcion'};
			$type =~ s/^\d\d-\d\d-\d\d\s//;
			if (!$type)
			{
				# if descriopcion is empty, it's the end of file totals line
				next;
			}
			if ($row->{'credito'})
			{
				$net=$row->{'credito'};
			}
			else
			{
				$net=$row->{'debito'};
			}
			$net =~ s/,//g;
			if ($row->{'debito'})
			{
				$net=-1 * $net;
			}
			$gross=$net;
			$mytype=$type;
			$currency="CRC";
		}	
		else
		{
			$date=$row->{'Date'};
			$type=$row->{'Type'};
			$net=$row->{'Net'};
			$gross=$row->{'Gross'};
			$itemtitle=$row->{'Item Title'};
			$currency=$row->{'Currency'};

			if (!$currency)
			{
				$currency="USD";
			}
			if ($type =~ /^(Website Payments Standard|PayPal Payments Standard|Website Payment)/)
			{
				$mytype="Payments Standard";
			}
			elsif ($type =~ /^(Website Payments Pro|PayPal Payments Pro)/)
			{
				$mytype="Payments Pro";
			}
			elsif ($type =~ /Express Checkout Payment/)
			{
				$mytype="Express Checkout";
			}
			elsif ($type =~ /^Bank Deposit to PP Account/)
			{
				$mytype="Bank Deposit to PP Account";
			}
			elsif ($type eq "Web Accept Payment Received")
			{
				$mytype="Web Accept";
			}
			elsif ($type eq "Shopping Cart Payment Received")
			{
				$mytype="Shopping Cart";
			}
			elsif ($type eq "Virtual Terminal Transaction")
			{
				$mytype="Virtual Terminal";
			}
			elsif ($type =~ /^(Refund|Withdraw Funds|Virtual Terminal|Temporary Hold|Update to eCheck Received|eBay Payment Sent|Payment Received|Request Sent|Donation Received|Direct Credit Card Payment|Payment Refund)/)
			{
				$mytype=$type;
			}
			elsif (exists($types{$type})) {
				$mytype = $types{$type};
			}
			elsif (!$row->{'Name'})
			{
				$mytype=$type;
			}
			else
			{
			# row will always exist (PayPal), but may be empty
				$mytype=$row->{'Name'};
			}

		}

		print {$handles{$currency}} "!Type:Cash\r\n";
		print {$handles{$currency}} "D${date}\r\n";
		print {$handles{$currency}} "T${net}\r\n";

#			print "found non-PP non temporary hold: $values[$fieldpos{'Name'}]\n";
		
		print {$handles{$currency}} "L$mytype\r\n";
		print {$handles{$currency}} "S$mytype\r\n";
# adjust gross (sales) if there is sales tax, and create tax liability split
		if ($source eq "paypal" and exists($row->{'Sales Tax'}) and $row->{'Sales Tax'} != 0)
		{
			my $tax = $row->{'Sales Tax'};
			if ($gross < 0) # seller purchase or refund/hold type transaction
			{
				if ($type eq "Payment Refund" or $type =~ /Hold.*for Dispute/)
				{
					$tax = abs($tax);
					$gross=$gross+$tax;
					$taxliability="SSales Tax Payable";
					if ($type eq "Payment Refund")
					{
						$taxliability.=" CORRECT ME";
						$refund_trans.="Date: $date\nType: $type\nAmount: $gross\nTotal Sales Tax Payable: $tax\n\n";
					}
					$taxliability.="\r\n\$-" . $tax . "\r\n";
				}
				
			}
			elsif ($type !~ /refund/i)
			{
				$gross=$gross-$tax;
				$taxliability="SSales Tax Payable\r\n";
				$taxliability.='$' . $tax . "\r\n";
			}
		}
		if ($shipsplit and $source eq "paypal" and exists($row->{'Shipping and Handling Amount'}) and $row->{'Shipping and Handling Amount'} != 0)
		{
			my $shipping = $row->{'Shipping and Handling Amount'};
			if ($gross < 0) # seller purchase or refund/hold type transaction
			{
				if ($type eq "Payment Refund"  or $type =~ /Hold.*for Dispute/)
				{
					$shipping = abs($shipping);
					$gross=$gross+$shipping;
					$shiphandling="SShipping and Handling Income";
					if ($type eq "Payment Refund")
					{
						$shiphandling.=" CORRECT ME";
						$refund_trans.="Date: $date\nType: $type\nAmount: $gross\nTotal Shipping and Handling Income: $shipping\n\n";
					}
					$shiphandling.="\r\n\$-" . $shipping . "\r\n";
				}
			}
			elsif ($type !~ /refund/i)
			{
				$gross=$gross-$shipping;
				$shiphandling="SShipping and Handling\r\n";
				$shiphandling.='$' . $shipping . "\r\n";
			}
		}
			
		print {$handles{$currency}} '$' . "$gross\r\n";
		print {$handles{$currency}} $taxliability;
		print {$handles{$currency}} $shiphandling;
		
		if ($source eq "paypal" and $row->{'Fee'} != 0)
		{
			print {$handles{$currency}} "SFee\r\n";
			print {$handles{$currency}} '$' . $row->{'Fee'} . "\r\n";
		}

		print {$handles{$currency}} "CX\r\n";
		print {$handles{$currency}} "P";
		if ($source eq "paypal" and $row->{'Name'})
		{
			print {$handles{$currency}} $row->{'Name'} . ": ";
		}
		if ($source eq "paypal" and exists($row->{'Item Title'}) and $row->{'Item Title'} ne "")
		{
			print {$handles{$currency}} "(" . $row->{'Item Title'} . ")";
		}
		else
		{
			print {$handles{$currency}} $type;
		}
		if ($source eq "paypal" and $type eq "Temporary Hold")
		{
			print {$handles{$currency}} " " . $row->{'Status'};
		}
		print {$handles{$currency}} "\r\n";
		print {$handles{$currency}} "^\r\n";
		# http://en.wikipedia.org/wiki/Quicken_Interchange_Format
		# http://svn.gnucash.org/trac/browser/gnucash/trunk/src/import-export/qif-import/file-format.txt
	}
	foreach my $currency (keys %handles) {
		close $handles{$currency};
	}
	close $fh;
	unlink "$base.m.csv";
	if ($refund_trans)
	{
		if (!open($fh,"+>:encoding(iso-8859-1)","$base.refund_warning.txt"))
		{
			print "Error: Could not open $base.refund_warning.txt for reading/writing.\n";
			next;
		}
		print $fh <<EOF;
I have found one or more refund transactions with either "Shipping and Handling Amount" or "Sales Tax" amounts.  I have created the respective reversal splits, but these splits will probably require manual adjustment, since I cannot know the amounts to be reversed. For example, a refund may return any portion of "Shipping and Handling" income. And a partial refund will reverse only a part of "Sales Tax Payable".

To allow easy adjustment of these splits, I have given them the names "Shipping and Handling Income CORRECT ME" and "Sales Tax Payable CORRECT ME." Upon import of the QIF into guncash, if any of these refund transactions should reverse less then 100% of sales tax payable or shipping and handling income, you should allow gnucash to create temporary accounts with these names, so manual adjustment of the split amounts can easily be made after QIF import.  Of course, if you import into these "CORRECT ME" accounts, you will need to change the account to your real "shipping and handling" income account and your "sales tax payable" liability account.

Details of each refund transaction involved are provided below.

EOF
		print $fh $refund_trans;
		close $fh;
	}
}

	
print "finished\n";
