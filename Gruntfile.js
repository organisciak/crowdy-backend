module.exports = function (grunt) {
    'use strict';
    // Project configuration
    grunt.initConfig({
        // Metadata
        pkg: grunt.file.readJSON('package.json'),
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
            '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
            '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
            '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
            ' Licensed <%= props.license %> */\n',
        // Task configuration
        concat: {
            options: {
                banner: '<%= banner %>',
                stripBanners: true
            },
            dist: {
                src: ['lib/crowdy-backend.js'],
                dest: 'dist/crowdy-backend.js'
            }
        },
        jshint: {
            options: {
                node: true,
                curly: true,
                eqeqeq: true,
                immed: true,
                latedef: true,
                newcap: true,
                noarg: true,
                sub: true,
                undef: true,
                unused: true,
                eqnull: true,
                browser: true,
                globals: { jQuery: true },
                boss: true
            },
            gruntfile: {
                src: 'Gruntfile.js'
            },
            app: {
                src: ['*.js', 'scripts/**/*.js', 'models/**/*.js', 'routes/**/*.js']
            }
        },
        coffeelint: {
            app: {
                src: ['*.coffee', 'scripts/**/*.coffee', 'models/**/*.coffee', 'routes/**/*.coffee']
            }
        },
        coffee: {
            options: {
                bare: true
            },
            app: {
                expand: true,
                src: '<%= coffeelint.app.src %>',
                ext: ".js"
            }
        },
        watch: {
            gruntfile: {
                files: '<%= jshint.gruntfile.src %>',
                tasks: ['jshint:gruntfile']
            },
            jslinter: {
                files: '<%= jshint.app.src %>',
                tasks: ['jshint:app']
            },
            coffee: {
                files: '<%= coffeelint.app.src %>',
                tasks: ['coffeelint', 'coffee']
            }
        }
    });

    // These plugins provide necessary tasks
    grunt.loadNpmTasks('grunt-contrib-concat');
    grunt.loadNpmTasks('grunt-contrib-jshint');
    grunt.loadNpmTasks('grunt-coffeelint');
    grunt.loadNpmTasks('grunt-contrib-watch');
    grunt.loadNpmTasks('grunt-contrib-coffee');

    // Default task
    grunt.registerTask('default', ['jshint', 'concat']);
};

