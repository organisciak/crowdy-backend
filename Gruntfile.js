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
                latedef: 'nofunc',
                newcap: true,
                noarg: true,
                sub: true,
                undef: true,
                unused: false,
                eqnull: true,
                browser: true,
                globals: { jQuery: true },
                boss: true
            },
            gruntfile: {
                src: 'Gruntfile.js'
            },
            app: {
                src: ['models/**/*.js', 'app.js', 'bin/www']
            }
        },
        coffeelint: {
            app: {
                src: ['*.coffee',
                        'scripts/**/*.coffee',
                        'models/**/*.coffee',
                        'routes/**/*.coffee'
                     ]
            },
            test: {
                src: ['test/**/*.coffee']
            },
            turk: {
                src: ['turk/**/*.coffee']
            }
        },
        docco: {
            turk: {
                src: ['<%= coffeelint.turk.src %>'],
                options: {
                    output: 'public/docs/'
                }
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
            turk: {
                files: '<%= coffeelint.turk.src %>',
                tasks: ['newer:coffeelint:turk', 'newer:docco:turk']
            },
            jslint: {
                files: '<%= jshint.app.src %>',
                tasks: ['newer:jshint:app']
            },
            coffee: {
                files: '<%= coffeelint.app.src %>',
                tasks: ['newer:coffeelint:app', 'newer:coffee:app']
            }
        }
    });

    // These plugins provide necessary tasks
    grunt.loadNpmTasks('grunt-contrib-concat');
    grunt.loadNpmTasks('grunt-contrib-jshint');
    grunt.loadNpmTasks('grunt-coffeelint');
    grunt.loadNpmTasks('grunt-contrib-watch');
    grunt.loadNpmTasks('grunt-contrib-coffee');
    grunt.loadNpmTasks('grunt-newer');
    grunt.loadNpmTasks('grunt-docco');

    // Default task
    grunt.registerTask('default', ['jshint', 'concat']);
};

