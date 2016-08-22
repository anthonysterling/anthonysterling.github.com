---
layout: post
title: Using an Artisan command to create a database in Laravel or Lumen
date: 2016-08-22
tags: [laravel, lumen]
---

We're heavy users of [Laravel][1] and [Lumen][2] here at [EvaluAgent][3], and we needed a way to automatically create the database for each of our services when we deployed them. A quick Google search provides mixed results, so I thought I'd blog our solution in an effort to help others.

We found that when using the built in `DB` functionality in Laravel/Lumen it attempted to connect to the non-existing database resulting in an exception being thrown,  so we decided to use the `env` to configure a native `PDO` connection to create database.

There may be a way to get the `PDO` connection directly from the `DB` Facade but, to be honest, time was short and we just needed to get on.

First we created a Artisan Command named `DatabaseCreateCommand` and then registered it, the source for this is below.

{% highlight php linenos %}
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use PDO;
use PDOException;

class DatabaseCreateCommand extends Command
{
    /**
     * The console command name.
     *
     * @var string
     */
    protected $name = 'db:create';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'This command creates a new database';

    /**
     * The console command signature.
     *
     * @var string
     */
    protected $signature = 'db:create';

    /**
     * Execute the console command.
     */
    public function fire()
    {
        $database = env('DB_DATABASE', false);

        if (! $database) {
            $this->info('Skipping creation of database as env(DB_DATABASE) is empty');
            return;
        }

        try {
            $pdo = $this->getPDOConnection(env('DB_HOST'), env('DB_PORT'), env('DB_USERNAME'), env('DB_PASSWORD'));

            $pdo->exec(sprintf(
                'CREATE DATABASE IF NOT EXISTS %s CHARACTER SET %s COLLATE %s;',
                $database,
                env('DB_CHARSET'),
                env('DB_COLLATION')
            ));

            $this->info(sprintf('Successfully created %s database', $database));
        } catch (PDOException $exception) {
            $this->error(sprintf('Failed to create %s database, %s', $database, $exception->getMessage()));
        }
    }

    /**
     * @param  string $host
     * @param  integer $port
     * @param  string $username
     * @param  string $password
     * @return PDO
     */
    private function getPDOConnection($host, $port, $username, $password)
    {
        return new PDO(sprintf('mysql:host=%s;port=%d;', $host, $port), $username, $password);
    }
}
{% endhighlight %}

Once we've deployed our services we can now just run the following commands to create the configured database and run the related migrations.

{% highlight bash linenos %}
php /var/www/artisan db:create
php /var/www/artisan db:migrate
{% endhighlight %}

I hope this helps.

[1]: https://laravel.com
[2]: https://lumen.laravel.com
[3]: http://www.evaluagent.net
