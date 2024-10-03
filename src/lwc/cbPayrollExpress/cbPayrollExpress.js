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
import {_applyDecStyle, _message, _parseServerError} from "c/cbUtils";
import getEmployeesServer from '@salesforce/apex/CBPayrollExpressPageController.getEmployeesServer';
import getDefaultBudgetYearIdServer from '@salesforce/apex/CBPayrollExpressPageController.getDefaultBudgetYearIdServer';
import checkSetupServer from '@salesforce/apex/CBPayrollExpressPageController.checkSetupServer';

export default class CBPayrollExpress extends LightningElement {

	@track showSpinner = false;
	@track readyToRender = false;
	@track showEmployeeDialog = false;
	@track employees = [];
	@track selectedEmployeeId;
	@track categoryTypes = []; // list of category types

	@track params = {};

	/** CHART */
	@track categoryIds = [];
	@track renderChart = false;
	/** CHART */

	async connectedCallback() {
		this.showSpinner = true;
		this.readyToRender = false;
		_applyDecStyle();
		await this.applyPreviousFilterOptions();
		console.log('Filters');
		await this.getListOfEmployee();
		console.log('Employees');
		this.getCategoryTypes();
		console.log('CategoryTypes');
		this.populateEmployeeRecords();
		console.log('EmployeeRecords');
		this.showSpinner = false;
		this.readyToRender = true;
		this.renderChart = true;
		this.checkSetup();
	};
	
	applyPreviousFilterOptions = async () => {
		['divisionId', 'budgetYearId', 'employeeId'].forEach(key => {
			const value = localStorage.getItem(key);
			if (value && value.length > 5) this.params[key] = value;
		});
		if (!this.params.budgetYearId) this.params.budgetYearId = await getDefaultBudgetYearIdServer();
	};

	/**
	 * Method gets a list of employees
	 */
	getListOfEmployee = async () => {
		this.categoryIds = [];
		this.renderChart = false;
		this.employees = await getEmployeesServer({params: this.params}).catch(e => _parseServerError('Get Employees Error: ', e));
	};

	getCategoryTypes = () => {
		try {
			this.categoryTypes = [];
			const categoryTypesObject = {};
			this.employees.forEach(emp => {
				emp.cb5p__CBCategories__r?.forEach(cat => {
					categoryTypesObject[cat.cb5p__Type__c] = true;
					this.categoryIds.push(cat.Id);
				});
			});
			this.categoryTypes = Object.keys(categoryTypesObject).sort();
		} catch (e) {
			_message('error', 'Category Types ' + e);
		}
	};

	populateEmployeeRecords = () => {
		try {
			this.employees.forEach((emp, idx) => {
				emp.idx = idx + 1;
				emp.total = 0;
				emp.divisionName = emp.cb5p__CBDivision__c ? emp.cb5p__CBDivision__r.Name : '-';
				emp.sic = emp.cb5p__SIC__c;
				emp.positionName = emp.cb5p__Position__c ? emp.cb5p__Position__c : '-';
				emp.categoryValues = [];
				this.categoryTypes.forEach(catName => emp.categoryValues.push(0));
				if (!emp.cb5p__CBCategories__r || emp.cb5p__CBCategories__r.length === 0) return null;
				this.categoryTypes.forEach((catName, idx) => {
					const category = emp.cb5p__CBCategories__r.find(cat => cat.cb5p__Type__c === catName);
					if (category) {
						emp.categoryValues[idx] += category.cb5p__Value__c;
						emp.total += +category.cb5p__Value__c;
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
	};

	handleChangeMainFilter = (event) => {
		if(event.target.name === 'budgetYearId' && !event.target.value) {
			return null;
		}
		this.params[event.target.name] = event.target.value;
		localStorage.setItem(event.target.name, event.target.value);

		console.log('event.target.name = ' + event.target.name + '   event.target.value=' + event.target.value);
		this.connectedCallback().then(r => null);
	};

	checkSetup = async () => {
		let setupIsOk = localStorage.getItem('setupIsOk');
		if (setupIsOk) return null;
		setupIsOk = await checkSetupServer();
		if (setupIsOk) {
			localStorage.setItem('setupIsOk', 'OK');
			return null;
		}
		_message('info', 'Please finish setup. Add the "Result" Type option to cb5__CBNonFinancialLibrary__c' +
			' and the "Payroll Template" option to cb5__CBFunction__c ');
	};


}