import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PipelineTabs from 'ee_else_ce/pipelines/components/pipeline_tabs.vue';
import { removeParams, updateHistory } from '~/lib/utils/url_utility';
import { TAB_QUERY_PARAM } from '~/pipelines/constants';
import { getPipelineDefaultTab, reportToSentry } from './utils';

Vue.use(VueApollo);

const createPipelineTabs = (selector, apolloProvider) => {
  const el = document.querySelector(selector);

  if (!el) return;

  const { dataset } = document.querySelector(selector);
  const {
    canGenerateCodequalityReports,
    codequalityReportDownloadPath,
    downloadablePathForReportType,
    exposeSecurityDashboard,
    exposeLicenseScanningData,
  } = dataset;

  const defaultTabValue = getPipelineDefaultTab(window.location.href);

  updateHistory({
    url: removeParams([TAB_QUERY_PARAM]),
    title: document.title,
    replace: true,
  });

  // eslint-disable-next-line no-new
  new Vue({
    el: selector,
    components: {
      PipelineTabs,
    },
    apolloProvider,
    provide: {
      canGenerateCodequalityReports: JSON.parse(canGenerateCodequalityReports),
      codequalityReportDownloadPath,
      defaultTabValue,
      downloadablePathForReportType,
      exposeSecurityDashboard: JSON.parse(exposeSecurityDashboard),
      exposeLicenseScanningData: JSON.parse(exposeLicenseScanningData),
    },
    errorCaptured(err, _vm, info) {
      reportToSentry('pipeline_tabs', `error: ${err}, info: ${info}`);
    },
    render(createElement) {
      return createElement(PipelineTabs);
    },
  });
};

export { createPipelineTabs };
