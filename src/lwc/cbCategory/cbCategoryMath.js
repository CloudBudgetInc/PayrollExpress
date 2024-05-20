let c; // context

const setContext = (_this) => c = _this;

const calculateResult = () => {
	const formula = c.category.cb5p__Formula__c;
	if (c.category.cb5p__TaxThreshold__c) return;
	if (c.category.cb5p__ParentCategory__c) {
		c.resultNFL.cb5__NonFinancialItems__r.forEach((item, idx) => {
			try {
				item.cb5__Value__c = c?.nfls[0].cb5__NonFinancialItems__r[idx].cb5__Value__c * c.category.cb5p__Allocation__c / 100;
			} catch (e) {
				item.cb5__Value__c = 0;
				console.error('Allocation Error: ' + e);
			}
		});
		return;
	}

	c.resultNFL.cb5__NonFinancialItems__r.forEach((item, idx) => {
		try {
			const args = c?.nfls.reduce((r, nfl, idx) => {
				const arg1 = nfl?.cb5__NonFinancialItems__r[idx]?.cb5__Value__c;
				if (arg1 !== undefined) r[`#${idx + 1}`] = arg1;
				return r;
			}, {});
			let updatedFormula = formula;
			Object.keys(args).forEach(key => updatedFormula = updatedFormula.replace(new RegExp(key, 'g'), args[key]));
			item.cb5__Value__c = eval(updatedFormula);
		} catch (e) {
			item.cb5__Value__c = 0;
			console.error('Formula Error: ' + e);
		}
	});
};

const calculateTotal = () => {
	const getTotal = (items) => {
		return items.reduce((total, item) => {
			total += +item.cb5__Value__c;
			return total;
		}, 0);
	};
	c.category.cb5p__Value__c = getTotal(c.resultNFL.cb5__NonFinancialItems__r);
};


export {setContext, calculateResult, calculateTotal};