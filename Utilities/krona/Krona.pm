# Copyright © 2011, Battelle National Biodefense Institute (BNBI);
# all rights reserved. Authored by: Brian Ondov, Nicholas Bergman, and
# Adam Phillippy
#
# See the LICENSE.txt file included with this software for license information.

use strict;

package Krona;


## version
#
my $version = '1.1';


use base 'Exporter';
use Cwd 'abs_path';

our @EXPORT = qw
(
	add
	footer
	getTaxID
	header
	loadTaxonomy
	lowestCommonAncestor
	newTree
	taxIDExists
	writeTree
);


our $footer =
'
	</data>
</html>
';

abs_path($0) =~ /(.*)\//;
my $scriptPath = $1;
my $taxonomyDir = $scriptPath;

my $javascript = "http://krona.sourceforge.net/krona-$version.js";
my $javascriptLocal = "$scriptPath/../src/krona-$version.js";
my $image = "http://krona.sourceforge.net/img/hidden.png";
my $imageLocal = "$scriptPath/../img/hidden.png";

my @depths;
my @parents;
my @ranks;
my @names;

sub add
{
	# tail-recursive function to add magnitude to specified node and all
	# ancestors (and create them if they doesn't exist)
	
	my ($set, $node, $taxID, $magnitude, $score) = @_;
	
	if ( ! @parents )
	{
		die 'Taxonomy not loaded. "loadTaxonomy()" must be called first.';
	}
	
	my $parent;
	
	if ( $parents[$taxID] != 1 )#$taxID )
	{
		$parent = add($set, $node, $parents[$taxID], $magnitude, $score);
	}
	else
	{
		$parent = $node;
		
		if ( ! defined $parent->{'magnitude'} )
		{
			$parent->{'magnitude'} = ();
		}
		
		$parent->{'magnitude'}[$set] += $magnitude;
	}
	
	if ( ! defined $parent->{'children'} )
	{
		$parent->{'children'} = ();
	}
	
	if ( $taxID != 1 )
	{
		my $name = $names[$taxID];
		
		if ( ! defined $parent->{'children'}{$name} )
		{
			$parent->{'children'}{$name} = ();
			
			my $newChild = $parent->{'children'}{$name};
			
			my @rank = ($ranks[$taxID]);
			$parent->{'children'}{$name}{'rank'} = \@rank;
			my @taxon = 
				("<a target='_blank' href='http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=$taxID'>$taxID</a>");
			$parent->{'children'}{$name}{'taxon'} = \@taxon;
			$parent->{'children'}{$name}{'magnitude'} = ();
			$parent->{'children'}{$name}{'scoreTotal'} = ();
			$parent->{'children'}{$name}{'scoreCount'} = ();
		}
		
		my $child = $parent->{'children'}{$name};
		
		${$child->{'magnitude'}}[$set] += $magnitude;
		
		if ( defined $score )
		{
			${$child->{'scoreTotal'}}[$set] += $score * $magnitude;
			${$child->{'scoreCount'}}[$set] += $magnitude;
		}
		
		return $child;
	}
}

sub ancestry
{
	my ($taxID) = @_;
	
	my @ancestors = ($taxID);
	
	while ( $taxID != 1 )
	{
		$taxID = $parents[$taxID];
		unshift @ancestors, $taxID;
	}
	
	return @ancestors;
}

sub dataHeader
{
	my
	(
		$magName,
		$attributes,
		$attributeDisplayNames,
		$datasetNames,
		$hueName,
		$hueStart,
		$hueEnd,
		$valueStart,
		$valueEnd
	) = @_;
	
	my $attributeString;
	my $colorString;
	
	for ( my $i = 0; $i < @$attributes; $i++ )
	{
		$attributeString .= " $$attributes[$i]=\"$$attributeDisplayNames[$i]\"";
	}
	
	if ( defined $hueName )
	{
		$colorString =
			"<color attribute=\"$hueName\" " .
			"hueStart=\"$hueStart\" hueEnd=\"$hueEnd\" " .
			"valueStart=\"$valueStart\" valueEnd=\"$valueEnd\"></color>";
	}
	
	return '
	<magnitude attribute="'. $magName . '"></magnitude>
	<attributes' . $attributeString . '></attributes>
	<datasets names="' . (join ',', @$datasetNames) . '"></datasets>
	' . "$colorString\n";
}

sub getTaxID
{
	my ($gi) = @_;
	
	open GI, "<$taxonomyDir/gi_taxid.dat" or die $!;
	
	seek GI, $gi * 4, 0;
	
	my $data;
	
	read GI, $data, 4;
	
	my $taxID = unpack "L", $data;
	
	close GI;
	
	if ( $taxID == 0 )
	{
		return 1;
	}
	else
	{
		return $taxID;
	}
}

sub header
{
	my
	(
		$local,
	) = @_;
	
	return '
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<meta charset="utf-8"/>
		<style>
			body
			{
				margin:0;
			}
		</style>
	</head>
	
	<body style="padding:0;position:relative">
		<div id="options" style="position:absolute;left:0;top:0">
		</div>
		
		<div id="details" style="position:absolute;top:1%;right:2%;text-align:right;">
		</div>
		
		<canvas id="canvas" width="100%" height="100%">
			This browser does not support HTML5 (see
			<a href="http://sourceforge.net/p/krona/wiki/Browser%20support/">
				Krona browser support</a>).
		</canvas>
		
		<img id="hiddenImage" src="' . ($local ? $imageLocal : $image) . '" visibility="hide"/>
		<script name="tree" src="' . ($local ? $javascriptLocal : $javascript) . '"></script>
	</body>
	
	<data>
';
}

sub loadTaxonomy
{
	open INFO, "<$taxonomyDir/taxonomy.tab" or die
		"Taxonomy not found.  Was updateTaxonomy.sh run?";
	
	while ( my $line = <INFO> )
	{
		chomp $line;
		my ($id, $depth, $parent, $rank, $name) = split /\t/, $line;
		
		$parents[$id] = $parent;
		$depths[$id] = $depth;
		$ranks[$id] = $rank;
		$names[$id] = $name;
	}
	
	close INFO;
}

sub lowestCommonAncestor
{
	my ($a, $b) = @_;
	
	# degenerate case optimizations
	#
	if ( $a == $b )
	{
		return $a;
	}
	#
	if ( $a == 1 || $b == 1 )
	{
		return 1;
	}
	
	# walk the nodes up to an equal depth
	#
	my $depthA = $depths[$a];
	my $depthB = $depths[$b];
	#
	while ( $depthA > $depthB )
	{
		$a = $parents[$a];
		$depthA--;
	}
	#
	while ( $depthB > $depthA )
	{
		$b = $parents[$b];
		$depthB--;
	}
	
	# now walk both up until they are equal
	#
	while ( $a != $b )
	{
		if ( $a == 1 || $b == 1 )
		{
			# one reached to top first; this shouldn't happen
			
			warn "No common ancestor found for $a and $b; $depthA $depthB";
			return 1;
		}
		
		$a = $parents[$a];
		$b = $parents[$b];
	}
	
	return $a;
}

sub newTree
{
	my %tree = ();
	return \%tree;
}

sub setScores
{
	my ($node, $logScore) = @_;
	
	my $min;
	my $max;
	
	if ( defined $node->{'scoreCount'} )
	{
		$node->{'score'} = ();
		
		for ( my $i = 0; $i < @{$node->{'scoreCount'}}; $i++ )
		{
			my $score;
			
			if ( ${$node->{'scoreCount'}}[$i] )
			{
				$score =
					${$node->{'scoreTotal'}}[$i] /
					${$node->{'scoreCount'}}[$i];
				
				if ( $logScore )
				{
					if ( $score > 0 )
					{
						$score = log $score;
					}
					else
					{
						$score = -413;
					}
				}
				
				if ( ! defined $min || $score < $min )
				{
					$min = $score;
				}
				
				if ( ! defined $max || $score > $max )
				{
					$max = $score;
				}
			}
			else
			{
				$score = 0;
			}
			
			${$node->{'score'}}[$i] = sprintf("%.2f", $score);
		}
	}
	
	if ( defined $node->{'children'} )
	{
		foreach my $child (keys %{$node->{'children'}})
		{
			my ($childMin, $childMax) =
				setScores($node->{'children'}{$child}, $logScore);
			
			if ( ! defined $min || $childMin < $min )
			{
				$min = $childMin;
			}
			
			if ( ! defined $max || $childMax > $max )
			{
				$max = $childMax;
			}
		}
	}
	
	return ($min, $max);
}

sub taxIDExists
{
	return defined $depths[$_[0]];
}

sub toStringXML
{
	my ($node, $name, $depth) = @_;
	
	my $htmlString = '';
	my $hueString = '';
	
	my $attributeString;
	my $colorString;
	
	if ( defined $node->{'scoreCount'} )
	{
	}
	
	foreach my $key ( keys %$node )
	{
		if ( $key ne 'children' && $key ne 'scoreCount' && $key ne 'scoreTotal' )
		{
			$attributeString .= (" $key=\"" . (join ',', @{$node->{$key}}) . '"');
		}
	}
	
	my $string = "\t" x $depth . "<node name=\"$name\"$attributeString>\n";
	
	if ( defined $node->{'children'} )
	{
		foreach my $child (keys %{$node->{'children'}})
		{
			$string .= toStringXML($node->{'children'}{$child}, $child, $depth + 1);
		}
	}
	
	return $string . "\t" x $depth . "</node>\n";
}

sub writeTree
{
	my
	(
		$tree,
		$rootName,
		$file,
		$local,
		$magName,
		$attributes,
		$attributeDisplayNames,
		$datasetNames,
		$logScore,
		$hueName,
		$hueStart,
		$hueEnd
	) = @_;
	
	my ($valueStart, $valueEnd);
	
	if ( defined $hueName )
	{
		($valueStart, $valueEnd) = setScores($tree, $logScore);
	}
	
	open OUT, ">$file";
	print OUT header($local);
	print OUT dataHeader
	(
		$magName,
		$attributes,
		$attributeDisplayNames,
		$datasetNames,
		$hueName,
		$hueStart,
		$hueEnd,
		$valueStart,
		$valueEnd
	);
	print OUT toStringXML($tree, $rootName, 1);
	print OUT $footer;
	close OUT;
}

1;
