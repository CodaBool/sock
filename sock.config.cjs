module.exports = {
  apps : [
    {
      script: 'typer.js',
      cron_restart: '0 10 * * *',
      // max_memory_restart: '100M',
      log_file: '/home/ec2-user/typer.log'
    },
    {
      script: 'slap.js',
      cron_restart: '0 10 * * *',
      // max_memory_restart: '100M',
      log_file: '/home/ec2-user/slap.log'
    }
  ]
}