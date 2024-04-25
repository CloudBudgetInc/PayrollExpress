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
import {api, LightningElement, track} from 'lwc';
import {_parseServerError} from "c/cbUtils";
import getEmployeesServer from '@salesforce/apex/CBPayrollExpressPageController.getEmployeesServer';
import getCategoriesServer from '@salesforce/apex/CBPayrollExpressPageController.getCategoriesServer';
import saveEmployeeServer from '@salesforce/apex/CBPayrollExpressPageController.saveEmployeeServer';
import saveNewCategoryServer from '@salesforce/apex/CBPayrollExpressPageController.saveNewCategoryServer';

export default class CBPayrollDialog extends LightningElement {

	@api recordId;
	@api budgetYearId;
	@api closeDialogFunction;
	@track showSpinner = false;
	@track showCategories = false;
	@track readyToRender = false;
	@track employee;
	@track categories;


	async connectedCallback() {
		this.readyToRender = false;
		this.showSpinner = true;
		await this.getEmployee();
		await this.getCategories();
		this.showSpinner = false;
		this.readyToRender = true;
	};

	getEmployee = async () => {
		try {
			const params = {budgetYearId: this.budgetYearId, employeeId: this.recordId};
			this.employee = await getEmployeesServer({params});
			this.employee = this.employee[0];
		} catch (e) {
			_parseServerError('Get Employee Error: ', e);
		}
	};

	getCategories = async () => {
		try {
			const params = {budgetYearId: this.budgetYearId, employeeId: this.recordId};
			this.categories = await getCategoriesServer({params});
			if (this.categories.length > 0) this.showCategories = true;
		} catch (e) {
			_parseServerError('Get Categories Error: ', e);
		}
	};

	closeDialog = () => {
		this.closeDialogFunction();
	};

	handleChange = (event) => {
		this.employee[event.target.name] = event.target.value;
	};

	/**
	 * The method saves Employee and categories
	 */
	saveEmployee = async () => {
		this.showSpinner = true;
		this.readyToRender = false;
		await saveEmployeeServer({employee: this.employee})
			.then(employee => {
				this.recordId = employee.Id;
				this.connectedCallback();
			})
			.catch(e => _parseServerError('Employee Saving Error: ', e));
	};

	refreshDialog = () => {
		this.connectedCallback();
	};

	addCategory = async () => {
		this.showCategories = false;
		try {
			const Index__c = this.categories ? this.categories.length + 1 : 1;
			const category = {
				Name: 'New',
				CBEmployee__c: this.employee.Id,
				CBBudgetYear__c: this.budgetYearId,
				Index__c,
				Type__c: 'Salary'
			};
			await saveNewCategoryServer({category});
			this.connectedCallback();
		} catch (e) {
			_parseServerError('Add New Category Error: ', e);
		}
	}

}