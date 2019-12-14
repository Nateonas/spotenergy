function getMedian(args) {
	if (args) { 
		if (!args.length) {return 0};
		var numbers = args.slice(0).sort(function(a,b){return a-b});
		var middle = Math.floor(numbers.length / 2);
		var isEven = numbers.length % 2 === 0;
		return isEven ? (numbers[middle] + numbers[middle - 1]) / 2 : numbers[middle];
	}
}

function getQuartiles(args) {
	if (args) { 
		if (!args.length) {return 0};
		var median = getMedian(args);
		var firstHalf = args.filter(function(f){return f < median});
		var secondHalf = args.filter(function(f){return f > median});
		console.log(firstHalf);
		console.log(secondHalf);
		var q1 = getMedian(firstHalf);
		var q3 = getMedian(secondHalf);
		return [q1,median,q3];
	}
}
