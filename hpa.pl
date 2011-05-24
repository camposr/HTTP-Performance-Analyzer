#!/usr/bin/perl
# 
# hpa.pl
# Http Performance Analyzer
#
## Copyright 2011, Rodrigo Albani de Campos (camposr@gmail.com)
## All rights reserved.
## 
## This program is free software, you can redistribute it and/or
## modify it under the terms of the "Artistic License 2.0".
##
## A copy of the "Artistic License 2.0" can be obtained at 
## http://www.opensource.org/licenses/artistic-license-2.0
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 
#
# Description:
# reads a slightly modified web server log file and
# generates a point chart with the arrival rate (hits/s) versus
# the average service time
# 
# the script expects that the last field of the log file is the total time
# the server took to serve the request
#
#
#
# TODO:
# *Add the following options
#  - Support milisecond service times (as in nginx)
#  - Support a destination path option for the chart
# *Code cleanup
# *Choose better variable names
# *Check for all modules and display a nifty message if any module is not found


use strict;
use Getopt::Std;

# The following modules are used to create the charts
use Chart::Clicker;
use Chart::Clicker::Renderer::Point;
use Chart::Clicker::Renderer::Area;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Graphics::Color::RGB;
use Graphics::Primitive::Brush;

# %hitcnt is a hit counter
# %svcacc is a service time accumulator
# %ts stands for throughtput and service time
#	this hash is used only to summarize results
use vars qw/*hitcnt *svcacc *ts @keys @svctime @hitcount/;

# a line counter, used to display progress and compute averages
my $lineno = 0;
# a counter used to store the number of single seconds
my $secondno = 0;
# 
my $svctimeSUM = 0;

while (<STDIN>)
{
	chomp();
	$lineno++;
	if (($lineno % 10000) == 0)
	{
			printf STDERR "Read %d lines\r",$lineno;
	}
	my ($date,$svctime) = (m/\[(\S+).+?\s(\d+)$/);
	$hitcnt{$date}++;
	$svcacc{$date} += $svctime;
	$svctimeSUM += ($svctime*10e-6);
}

while (my ($key,$value) = each %hitcnt)
{
	$ts{$value}[0] += $svcacc{$key};
	$ts{$value}[1] += $value;
	$secondno++;
}

# dump results
# and create datasets

my $HitsPerSecondAVG = ($lineno/$secondno);
my $ServiceTimeAVG = ($svctimeSUM/$lineno);


print "throughput;svck;count\n";


for my $t (sort { $a <=> $b } keys %ts)
{
	next if ($ts{$t}[1] < 20);
	printf("%d;%f;%d\n",$t,($ts{$t}[0]/$ts{$t}[1])*10e-6,$ts{$t}[1]);
	push @keys, $t;
	push @svctime, ($ts{$t}[0]/$ts{$t}[1])*10e-6;
	push @hitcount, $ts{$t}[1];
}

print "Average Hits/s = $HitsPerSecondAVG\n";
print "Average Service time = $ServiceTimeAVG\n";
print "Utilization = ".$HitsPerSecondAVG*$ServiceTimeAVG."\n";


my $svctimeseries = Chart::Clicker::Data::Series->new(
	name => 'Service Time(s)',
	keys => \@keys,
	values => \@svctime,
);

my $svctimeds = Chart::Clicker::Data::DataSet->new(series => [ $svctimeseries ]);


my $hitcountseries = Chart::Clicker::Data::Series->new(
	name => 'Hit Count',
	keys => \@keys,
	values => \@hitcount,
);

my $hitcountds = Chart::Clicker::Data::DataSet->new(series => [ $hitcountseries ]);

# generate graph

my $cc = Chart::Clicker->new(width => 800, height => 400);

$cc->title->text("Throughtput and Service time");
$cc->title->padding->bottom(5);


my $defctx = $cc->get_context('default');
my $octx = Chart::Clicker::Context->new( name => 'freq' );

$hitcountds->context('freq');

$cc->add_to_contexts($octx);


$cc->add_to_datasets($svctimeds);
$cc->add_to_datasets($hitcountds);

$defctx->renderer(Chart::Clicker::Renderer::Point->new);
$octx->renderer(Chart::Clicker::Renderer::Area->new(opacity => .4));
$defctx->domain_axis->label('Throughput');
$octx->range_axis->label('Hit_Count');
$defctx->range_axis->label('Service_time(s)');

$cc->write_output('out.png');


