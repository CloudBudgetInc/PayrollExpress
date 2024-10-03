/**
Copyright (c) 05 2024, AJR
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
import chartjs from '@salesforce/resourceUrl/cb5__ChartJs';
import {loadScript} from 'lightning/platformResourceLoader';
import getChartDataServer from '@salesforce/apex/CBPayrollExpressPageController.getChartDataServer';
import {_message, _parseServerError} from "c/cbUtils";
import {getNextColor} from "./cbPayrollChartColors";

export default class CBPayrollChart extends LightningElement {

	@api params;
	@api budgetYearId;

	@track chartData;
	@track employeeChartConfig;
	@track typeBarChartConfig;
	@track typeMonthChartConfig;
	@track isChartJsInitialized;
	@track chartPlaceHolder = `To remove this placeholder, go to SETUP, open "Session Settings"and check "Use Lightning Web Security for Lightning web components" under "Lightning Web Security" and Save`;
	@track showPlaceHolder = false;
	@track showChart = true;

	async renderedCallback() {
		try {
			if (this.isChartJsInitialized) {
				return;
			}
			await this.getChartData();
			this.setTypeMonthChartData();
			this.setTypeChartData();
			this.setEmployeePieData();
			this.renderCharts();
		} catch (e) {
			_message('error', 'renderedCallback Error: ' + JSON.stringify(e));
		}
	}

	renderCharts = () => {
		Promise.all([loadScript(this, chartjs)])
			.then(() => {
				try {
					this.isChartJsInitialized = true;

					const typeMonthContext = this.template.querySelector('canvas.typeMonthChart').getContext('2d');
					new window.Chart(typeMonthContext, JSON.parse(JSON.stringify(this.typeMonthChartConfig)));

					const typeBarContext = this.template.querySelector('canvas.typeChart').getContext('2d');
					new window.Chart(typeBarContext, JSON.parse(JSON.stringify(this.typeBarChartConfig)));

					const employeeContext = this.template.querySelector('canvas.empChart').getContext('2d');
					new window.Chart(employeeContext, JSON.parse(JSON.stringify(this.employeeChartConfig)));
				} catch (e) {
					console.error('Promise callback error: ' + JSON.stringify(e));
				}

			})
			.catch(e => {
				this.showPlaceHolder = true;
				this.showChart = false;
			});
	};

	/**
	 * Method gets a list of ChartWrapper for the chart
	 */
	getChartData = async () => {
		const params = {
			categoryIds: this.params,
			budgetYearId: this.budgetYearId
		};
		this.chartData = await getChartDataServer(params).catch(e => _parseServerError('Get Chart Data Error : ', e));
	};

	setTypeMonthChartData = () => {
		try {
			const tpv = this.chartData.typePeriodValue;
			if(!tpv) return null;
			let types = Object.keys(tpv);
			const customSort = (array) => {
				return array.sort((a, b) => {
					if (a === "TOTAL") return -1; // TOTAL should come first
					if (b === "TOTAL") return 1;
					if (a === "Salary") return -1; // Salary should come after TOTAL
					if (b === "Salary") return 1;
					return a.localeCompare(b); // All other strings sorted alphabetically
				});
			};
			types = customSort(types);
			const l = tpv[types[0]];
			if(!l) return null;
			const labels = Object.keys(l);
			const datasets = [];
			types.forEach(type => {
				try {
					const dt = {
						label: type,
						data: Object.values(tpv[type]),
						borderColor: getNextColor(),
						fill: false
					};
					datasets.push(dt);
				} catch (e) {
					console.error('setTypeMonthChartData types error: ' + JSON.stringify(e));
				}
			});

			this.typeMonthChartConfig = {
				type: 'line',
				data: {
					labels,
					datasets
				},
				options: {
					scales: {
						y: {
							beginAtZero: true
						}
					}
				}
			};
		} catch (e) {
			_message('error', 'setTypeMonthChartData Error: ' + e);
		}
	};

	setTypeChartData = () => {
		try {
			const tv = this.chartData.typeValue;
			const backgroundColor = Object.keys(tv).map(c => getNextColor());
			const chartData = {
				labels: Object.keys(tv),
				datasets: [{
					label: 'By Type',
					data: Object.values(tv),
					backgroundColor,
					hoverOffset: 4
				}]
			};
			this.typeBarChartConfig = {
				type: 'bar',
				data: chartData,
				options: {
					scales: {
						y: {
							beginAtZero: true,
							ticks: {
								callback: function (value, index, values) {
									return '$' + value.toLocaleString(); // Format y-axis labels as dollars
								}
							}
						}
					},
					plugins: {
						tooltip: {
							callbacks: {
								label: function (context) {
									let label = context.dataset.label || '';
									if (label) {
										label += ': ';
									}
									if (context.parsed.y !== null) {
										label += '$' + context.parsed.y.toLocaleString(); // Format tooltips as dollars
									}
									return label;
								}
							}
						}
					}
				}
			};
		} catch (e) {
			_message('error', 'setTypeChartData Error: ' + JSON.stringify(e))
		}
	};

	setEmployeePieData = () => {
		const emp = this.chartData.employeeValue;
		const backgroundColor = Object.keys(emp).map(c => getNextColor());
		const chartData = {
			labels: Object.keys(emp),
			datasets: [{
				label: 'Expenditures',
				data: Object.values(emp),
				backgroundColor,
				hoverOffset: 4
			}]
		};
		this.employeeChartConfig = {
			type: 'doughnut',
			data: chartData
		};
	};

}