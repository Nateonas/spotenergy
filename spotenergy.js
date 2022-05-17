function getMedian(args) {
	if (args) { 
		if (!args.length) {return 0};
		var numbers = args.slice(0).sort(function(a,b){return a-b});
		var middle = Math.floor(numbers.length / 2);
		var isEven = numbers.length % 2 === 0;
		return isEven ? (numbers[middle] + numbers[middle - 1]) / 2 : numbers[middle];
	}
}

function getQuartilesMedian(args) {
	if (args) { 
		if (!args.length) {return 0};
		var median = getMedian(args);
		var firstHalf = args.filter(function(f){return f < median});
		var secondHalf = args.filter(function(f){return f > median});
		var q1 = getMedian(firstHalf);
		var q3 = getMedian(secondHalf);
		return [q1,median,q3];
	}
}

function getAverage(args) {
        if (args) {
                if (!args.length) {return 0};
                return args.reduce(function(p,c,i,a){return p + (c/a.length)},0);
        }
}

function getQuartilesAverage(args) {
	if (args) { 
		if (!args.length) {return 0};
		var average = getAverage(args);
		var firstHalf = args.filter(function(f){return f < average});
		var secondHalf = args.filter(function(f){return f > average});
		var q1 = getAverage(firstHalf);
		var q3 = getAverage(secondHalf);
		return [q1,average,q3];
	}
}
