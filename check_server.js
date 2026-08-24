const { NodeSSH } = require('node-ssh');
const ssh = new NodeSSH();

async function check() {
  try {
    console.log('Connecting to server...');
    await ssh.connect({
      host: '103.247.8.67',
      username: 'root',
      password: '47BnR%sB5!77AE'
    });
    console.log('Connected!');

    console.log('Checking docker...');
    let res = await ssh.execCommand('docker --version');
    console.log('Docker:', res.stdout);

    console.log('Checking files...');
    res = await ssh.execCommand('ls -la');
    console.log('Files:', res.stdout);

    ssh.dispose();
  } catch (err) {
    console.error(err);
  }
}
check();
