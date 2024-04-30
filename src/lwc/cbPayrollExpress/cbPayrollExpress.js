/**
Copyright (c) 10 2023, AJR
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
 * Neither the name of the CloudBudget, Inc. nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.

 */
import {LightningElement, track} from 'lwc';
import {_message, _parseServerError, _applyDecStyle} from "c/cbUtils";
import getEmployeesServer from '@salesforce/apex/CBPayrollExpressPageController.getEmployeesServer';
import getAnalyticsServer from '@salesforce/apex/CBPayrollExpressPageController.getAnalyticsServer';

export default class CBPayrollExpress extends LightningElement {

	@track showSpinner = false;
	@track readyToRender = false;
	@track showEmployeeDialog = false;
	@track employees = [];
	@track selectedEmployeeId;

	@track divisionSO = [];
	@track budgetYearSO = [];
	@track employeeSO = [];
	@track categoryTypes = []; // list of category types

	@track params = {};


	async connectedCallback() {
		this.showSpinner = true;
		this.readyToRender = false;
		_applyDecStyle();
		await this.getAnalytics();
		await this.getListOfEmployee();
		this.getCategoryTypes();
		this.populateEmployeeRecords();
		this.showSpinner = false;
		this.readyToRender = true;

	};

	getAnalytics = async () => {
		try {
			const analytics = await getAnalyticsServer();
			this.divisionSO = this.convertObjectToListOfSO(analytics['division'], true);
			this.budgetYearSO = this.convertObjectToListOfSO(analytics['budgetYear'], false);
			this.employeeSO = this.convertObjectToListOfSO(analytics['employee'], true);
		} catch (e) {
			_parseServerError('Get Employees Error: ', e);
		}
	};

	convertObjectToListOfSO = (obj, allOptionNeeded) => {
		const options = Object.keys(obj).map(key => ({value: key, label: obj[key]}));
		if (allOptionNeeded) options.unshift({value: '', label: 'All'});
		return options;
	};

	getListOfEmployee = async () => {
		if (!this.params.budgetYearId) {
			this.params.budgetYearId = this.budgetYearSO[0].value;
		}
		await getEmployeesServer({params: this.params})
			.then(employees => {
				this.employees = employees;
			})
			.catch(e => _parseServerError('Get Employees Error: ', e))
	};

	getCategoryTypes = () => {
		try {
			this.categoryTypes = [];
			const categoryTypesObject = {};
			this.employees.forEach(emp => {
				emp.CBCategories__r?.forEach(cat => categoryTypesObject[cat.Type__c] = true);
			});
			this.categoryTypes = Object.keys(categoryTypesObject).sort();
		} catch (e) {
			_message('error', 'Category Types ' + e);
		}
	};

	populateEmployeeRecords = () => {
		try {
			if (this.categoryTypes.length === 0) return null;
			this.employees.forEach(emp => {
				emp.total = 0;
				emp.divisionName = emp.CBDivision__c ? emp.CBDivision__r.Name : '-';
				emp.positionName = emp.Position__c ? emp.Position__c : '-';
				emp.categoryValues = [];
				this.categoryTypes.forEach(catName => emp.categoryValues.push(0));
				if (!emp.CBCategories__r || emp.CBCategories__r.length === 0) return null;
				this.categoryTypes.forEach((catName, idx) => {
					const category = emp.CBCategories__r.find(cat => cat.Type__c === catName);
					if (category) {
						emp.categoryValues[idx] += category.Value__c;
						emp.total += +category.Value__c;
					}
				});
			});
		} catch (e) {
			_message('error', 'Category Types ' + e);
		}
	};

	openEmployeeDialog = (event) => {
		this.selectedEmployeeId = event.target.id.slice(0, 15);
		this.showEmployeeDialog = true;
	};

	closeEmployeeDialog = async () => {
		this.showEmployeeDialog = false;
		await this.connectedCallback();
	}


}