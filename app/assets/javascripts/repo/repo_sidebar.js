import Vue from 'vue';
import Service from './repo_service';
import Helper from './repo_helper';
import Store from './repo_store';
import RepoPreviousDirectory from './repo_prev_directory';
import RepoFileOptions from './repo_file_options';
import RepoFile from './repo_file';
import RepoLoadingFile from './repo_loading_file';
import RepoMiniMixin from './repo_mini_mixin';

export default class RepoSidebar {
  constructor(el) {
    this.initVue(el);
  }

  initVue(el) {
    this.vue = new Vue({
      el,
      mixins: [RepoMiniMixin],
      components: {
        'repo-file-options': RepoFileOptions,
        'repo-previous-directory': RepoPreviousDirectory,
        'repo-file': RepoFile,
        'repo-loading-file': RepoLoadingFile,
      },

      created() {
        this.addPopEventListener();
      },

      data: () => Store,

      methods: {
        addPopEventListener() {
          window.addEventListener('popstate', () => {
            if (location.href.indexOf('#') > -1) return;
            this.linkClicked({
              url: location.href,
            });
          });
        },

        linkClicked(file) {
          let url = '';
          if (typeof file === 'object') {
            if (file.type === 'tree' && file.opened) {
              Helper.removeChildFilesOfTree(file);
            }
            url = file.url;
            Service.url = url;
            Helper.getContent(file);
          } else if (typeof file === 'string') {
            // go back
            url = file;
            Service.url = url;
            Helper.getContent();
          }
        },
      },
    });
  }
}
