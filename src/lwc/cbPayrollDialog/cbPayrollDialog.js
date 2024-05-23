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
import {_confirm, _message, _parseServerError, _prompt} from "c/cbUtils";
import getEmployeesServer from '@salesforce/apex/CBPayrollExpressPageController.getEmployeesServer';
import getCategoriesServer from '@salesforce/apex/CBPayrollExpressPageController.getCategoriesServer';
import saveEmployeeServer from '@salesforce/apex/CBPayrollExpressPageController.saveEmployeeServer';
import saveNewCategoryServer from '@salesforce/apex/CBPayrollExpressPageController.saveNewCategoryServer';
import savePayrollTemplateServer from '@salesforce/apex/CBPayrollTemplatePageController.savePayrollTemplateServer';
import getFunctionsServer from '@salesforce/apex/CBPayrollTemplatePageController.getFunctionsServer';
import applyPayrollTemplateServer from '@salesforce/apex/CBPayrollTemplatePageController.applyPayrollTemplateServer';

export default class CBPayrollDialog extends LightningElement {

	@api recordId;
	@api budgetYearId;
	@api closeDialogFunction;
	@track showSpinner = false;
	@track showCategories = false;
	@track readyToRender = false;
	@track employee;
	@track categories;
	@track functionSO = [];


	async connectedCallback() {
		this.readyToRender = false;
		this.showSpinner = true;
		await this.getEmployee();
		await this.getCategories();
		this.colorAllocatedGroup();
		this.showSpinner = false;
		this.readyToRender = true;
		this.getFunctions();
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
		const params = {employee: this.employee, byId: this.budgetYearId};
		console.log('PARAMS: ' + JSON.stringify(params));
		await saveEmployeeServer({employee: this.employee, byId: this.budgetYearId})
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
			const cb5p__Index__c = this.categories ? this.categories.length + 1 : 1;
			const category = {
				Name: 'New',
				cb5p__CBEmployee__c: this.employee.Id,
				cb5p__CBBudgetYear__c: this.budgetYearId,
				cb5p__Index__c,
				cb5p__Type__c: 'Salary'
			};
			await saveNewCategoryServer({category});
			this.connectedCallback();
		} catch (e) {
			_parseServerError('Add New Category Error: ', e);
		}
	};

	colorAllocatedGroup = () => {
		const categoryMap = {};
		this.categories.forEach(cat => {
			const key = cat.cb5p__ParentCategory__c ? cat.cb5p__ParentCategory__c : cat.Id;
			let catArray = categoryMap[key];
			if (!catArray) {
				catArray = [];
				categoryMap[key] = catArray;
			}
			catArray.push(cat);
		});
		const colors = ['red', 'green', 'blue', 'yellow', 'orange'];
		let currentColorIndex = -1;
		const getNextColor = () => {
			currentColorIndex++;
			return colors[currentColorIndex];
		};
		Object.keys(categoryMap).forEach(key => {
			const catArray = categoryMap[key];
			if (catArray.length < 2) return null;
			const color = getNextColor();
			catArray.forEach(cat => cat.styleClass = color);
		})
	};

	savePayrollTemplate = async () => {
		const title = await _prompt('Put some title', 'New', 'Title');
		if (!title) return;
		savePayrollTemplateServer({
			title,
			empId: this.employee.Id,
			byId: this.budgetYearId
		}).catch(e => _parseServerError('Saving Error :', e));
	};

	getFunctions = async () => {
		const functions = await getFunctionsServer().catch(e => _parseServerError('Get Function Error: ', e));
		if (!functions) return;
		this.functionSO = functions.map(f => ({value: f.Id, label: f.Name}));
	};

	@track funcId;
	handleConfigChange = (event) => {
		this.funcId = event.target.value;
	};

	applyConfiguration = async () => {
		const confirmed = await _confirm('Current categories will be replaced with categories from the template. Are you sure?');
		if (!confirmed) {
			this.funcId = undefined;
			return null;
		}
		this.readyToRender = false;
		this.showSpinner = true;
		await applyPayrollTemplateServer({
			funcId: this.funcId,
			empId: this.employee.Id,
			byId: this.budgetYearId
		}).catch(e => _parseServerError('Application Error : ', e));
		this.funcId = undefined;
		_message('success', 'Applied');
		this.connectedCallback();
	};


}