pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to run'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['test', 'prod'],
            description: 'Target environment'
        )
        // --- Required for all actions ---
        string(name: 'VM_NAME',           description: 'VM name to have')
        string(name: 'POOL',              description: 'Libvirt storage pool name')

        // --- Required for plan/apply only (not needed for destroy) ---
        string(name: 'MAC_ADDRESS',       description: '[plan/apply] MAC address for macvtap interface (must be lowercase)')
        string(name: 'POOL_TARGET_PATH',  description: '[plan/apply] Filesystem path where the pool stores volumes')
        string(name: 'BASE_VOLUME_NAME',  description: '[plan/apply] Base qcow2 image filename in the pool')
        string(name: 'MEMORY',            defaultValue: '1024',    description: '[plan/apply] RAM in MiB')
        string(name: 'VCPU',              defaultValue: '2',       description: '[plan/apply] vCPU count')
        string(name: 'DISK_SIZE',         defaultValue: '20',      description: '[plan/apply] Disk size in GiB (must be >= base image virtual size)')
        string(name: 'MACVTAP_INTERFACE', defaultValue: 'enp0s25', description: '[plan/apply] Physical NIC for macvtap')
        string(name: 'NETWORK_NAME', description: '[plan/apply] Libvirt network name for secondary interface (e.g. default)')
        string(name: 'DATA_DISK_DEVICE', description: '[plan/apply] Path to a pre-existing raw block device for a second disk (e.g. /dev/zvol/data_disk/<vm>-volume). Leave blank if the VM has no external data disk.')
        booleanParam(name: 'NESTED_VIRT', defaultValue: false, description: '[plan/apply] Expose host CPU virtualization features (vmx/svm) to the guest. Required for VMs that themselves run KVM/QEMU (e.g. a Packer/QEMU build VM). Also requires nested virtualization enabled on the physical host.')
    }

    environment {
        TF_DIR     = 'hosts'

        TF_LOG     = 'INFO'

        // Terraform picks up TF_VAR_* automatically — no -var flags needed in commands
        TF_VAR_name              = "${params.VM_NAME}"
        TF_VAR_mac_address       = "${params.MAC_ADDRESS}"
        TF_VAR_pool              = "${params.POOL}"
        TF_VAR_pool_target_path  = "${params.POOL_TARGET_PATH}"
        TF_VAR_base_volume_name  = "${params.BASE_VOLUME_NAME}"
        TF_VAR_memory            = "${params.MEMORY}"
        TF_VAR_vcpu              = "${params.VCPU}"
        TF_VAR_disk_size         = "${params.DISK_SIZE}"
        TF_VAR_macvtap_interface = "${params.MACVTAP_INTERFACE}"
        TF_VAR_network_name      = "${params.NETWORK_NAME}"
        TF_VAR_data_disk_device  = "${params.DATA_DISK_DEVICE}"
        TF_VAR_nested_virt       = "${params.NESTED_VIRT}"
    }

    stages {
        stage('Init') {
            steps {
                withCredentials([string(credentialsId: 'TF_STATE_BASE_PATH', variable: 'TF_STATE_BASE_PATH')]) {
                    script {
                        env.STATE_PATH = "${env.TF_STATE_BASE_PATH}/${params.ENVIRONMENT}/${params.VM_NAME}.tfstate"
                    }
                    dir(env.TF_DIR) {
                        sh """
                            echo "=== STATE_PATH: ${env.STATE_PATH} ==="
                            terraform version
                            terraform init \
                              -backend-config="path=${env.STATE_PATH}" \
                              -reconfigure
                        """
                    }
                }
            }
        }

        stage('Plan') {
            when { expression { params.ACTION in ['plan', 'apply'] } }
            steps {
                script {
                    def credId = params.ENVIRONMENT == 'prod' ? 'prod-libvirt-uri' : 'test-libvirt-uri'
                    withCredentials([
                        string(credentialsId: credId, variable: 'BASE_LIBVIRT_URI'),
                        sshUserPrivateKey(credentialsId: 'jenkins-automation-user', keyFileVariable: 'SSH_KEY_FILE')
                    ]) {
                        withEnv(["TF_VAR_libvirt_uri=${env.BASE_LIBVIRT_URI}?keyfile=${env.SSH_KEY_FILE}"]) {
                            dir(env.TF_DIR) {
                                sh """
                                    echo "=== SSH key file path: ${env.SSH_KEY_FILE} ==="
                                    ls -la ${env.SSH_KEY_FILE}
                                    echo "=== TF_VAR_libvirt_uri is set: \$([ -n \"\$TF_VAR_libvirt_uri\" ] && echo yes || echo no) ==="
                                    terraform plan
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    def credId = params.ENVIRONMENT == 'prod' ? 'prod-libvirt-uri' : 'test-libvirt-uri'
                    withCredentials([
                        string(credentialsId: credId, variable: 'BASE_LIBVIRT_URI'),
                        sshUserPrivateKey(credentialsId: 'jenkins-automation-user', keyFileVariable: 'SSH_KEY_FILE')
                    ]) {
                        withEnv(["TF_VAR_libvirt_uri=${env.BASE_LIBVIRT_URI}?keyfile=${env.SSH_KEY_FILE}"]) {
                            dir(env.TF_DIR) {
                                sh 'terraform apply -auto-approve'
                            }
                        }
                    }
                }
            }
        }

        stage('Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
               // input message: "Destroy VM '${params.VM_NAME}' in ${params.ENVIRONMENT}? This cannot be undone."
                script {
                    def credId = params.ENVIRONMENT == 'prod' ? 'prod-libvirt-uri' : 'test-libvirt-uri'
                    withCredentials([
                        string(credentialsId: credId, variable: 'BASE_LIBVIRT_URI'),
                        sshUserPrivateKey(credentialsId: 'jenkins-automation-user', keyFileVariable: 'SSH_KEY_FILE')
                    ]) {
                        withEnv(["TF_VAR_libvirt_uri=${env.BASE_LIBVIRT_URI}?keyfile=${env.SSH_KEY_FILE}"]) {
                            dir(env.TF_DIR) {
                                sh 'terraform destroy -auto-approve'
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            slackSend(
                color: "danger",
                message: "Terraform ${params.ACTION} failed for VM '${params.VM_NAME}' in ${params.ENVIRONMENT}"
            )
        }
        success {
            slackSend(
                color: "good",
                message: "Terraform ${params.ACTION} completed for VM '${params.VM_NAME}' in ${params.ENVIRONMENT}"
            )
        }
    }
}
