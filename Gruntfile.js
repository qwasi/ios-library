
var fs = require('fs');
var util = require('util');

module.exports = function(grunt) {

    var semverUtils = require('semver-utils');

    var getBuildVersion = function() {
	var package = grunt.file.readJSON('package.json');
	var semver = semverUtils.parse(package.version);

	var release = semver.release ? semver.release.split('.') : 1000;

	if (Array.isArray(release)) {
		release = +release[release.length-1];
	}
	return release;
    }
    
    // Do grunt-related things in here
    require('load-grunt-tasks')(grunt);
    grunt.initConfig({
	getPackage: function() { return grunt.file.readJSON('package.json'); },
	package: grunt.file.readJSON('package.json'),
	gitcheckout: {
    	    default: {
      		options: {
		    create: false
		}
   	    }
  	},
	changelog: {
	    'ios-library': {
		options: {
            	    featureRegex: /^(.*)implements (IOSSDK-\d+)(.*)/gi,
            	    fixRegex: /^(.*)fixes (IOSSDK-\d+)(.*)/gi,
            	    dest: 'CHANGELOG.md',
            	    template: '## SDK Version <%= getPackage().version %> / {{date}}\n\n{{> features}}{{> fixes}}',
            	    partials: {
                	features: '{{#each features}}{{> feature}}{{/each}}',
                	feature: '- [NEW] {{this}}\n',
                	fixes: '{{#each fixes}}{{> fix}}{{/each}}',
                	fix: "- [FIX] {{this}}\n"
            	    }
        	}
	    }
	},
	replace: {
	    changelog: {
		options: {
		    patterns: [ {
			match: /(IOSSDK-\d+)/g,
			replacement: '[$1](https://jira.qwasi.com/browse/$1)'
		    }]
		},
		files: [
		    { expand: true, flatten: true, src: ['CHANGELOG.md'] }
		]
	    }
	},	
	bump: {
	    options: {
		files: ['package.json'],
		updateConfigs: [],
		commit: true,
		commitMessage: '#bump v%VERSION%',
		commitFiles: ['package.json'],
		createTag: true,
		tagName: '%VERSION%',
		tagMessage: 'Version %VERSION%',
		push: false,
		pushTo: 'origin',
		prereleaseName: false,
		gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d',
		globalReplace: false
	    }
	},
	shell: {
	    bump_pod: {
		command: function() {
		    var package = grunt.file.readJSON('package.json');
		    var semver = semverUtils.parse(package.version);

		    return 'podspec-bump -w ' + semver;
		}
	    }
	}
    });

    grunt.registerTask('changeLog', 'Build changelog and add jira links', ['changelog', 'replace']);

    grunt.registerTask('bump-all', ['bump-only:patch', 'shell', 'writeVersionHeader', 'changelog']);

    grunt.registerTask('writeVersionHeader', function() {
	var package = grunt.file.readJSON('package.json');
	var semver = semverUtils.parse(package.version);
	
	var header = util.format('\/\/ Version Header\n' + 
				 '#define SHORT_VERSION @"%s"\n' +
				 '#define BUILD_VERSION %d\n' +
				 '#define VERSION_STRING @"%s-%d" \n'
				 , semver.version, getBuildVersion(), semver.version, getBuildVersion());
	
	fs.writeFileSync('Pod/Classes/Version.h', header);
	
    });

};
