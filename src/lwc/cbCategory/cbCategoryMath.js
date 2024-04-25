import {_message} from "c/cbUtils";

let c; // context

const setContext = (_this) => c = _this;

const calculateResult = () => {
	const formula = c.category.Formula__c;
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
			item.cb5__Value__c = -1;
			_message('error', 'Formula Error: ' + e);
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
	c.category.Value__c = getTotal(c.resultNFL.cb5__NonFinancialItems__r);
};


export {setContext, calculateResult, calculateTotal};