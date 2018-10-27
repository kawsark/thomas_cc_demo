# Deploy a Vault Server

# Render userdata
data "template_file" "startup_script" {
  template = "${file("${path.module}/init_vault.tpl")}"
  vars {
    mongo_server_ip = "${aws_instance.mongo.0.private_ip}"
  }
}

resource aws_instance "vault" {
    ami       = "${data.aws_ami.vault.id}"
    count			= "1"
    instance_type		= "${var.client_machine_type}"
    key_name			= "${var.ssh_key_name}"
    subnet_id			= "${element(data.aws_subnet_ids.default.ids, count.index)}"
    associate_public_ip_address = true
    vpc_security_group_ids      = ["${aws_security_group.vault_server_sg.id}"]
    iam_instance_profile        = "${aws_iam_instance_profile.consul_client_iam_profile.name}"

    tags = "${merge(var.hashi_tags, map("Name", "${var.project_name}-vault-server-${count.index}"), map("role", "vault-server"), map("consul-cluster-name", replace("consul-cluster-${var.project_name}-${var.hashi_tags["owner"]}", " ", "")))}"
    user_data  = "${data.template_file.startup_script.rendered}"
}

output "vault_servers" {
    value = ["${aws_instance.vault.*.public_dns}"]
}

# Security groups

resource aws_security_group "vault_server_sg" {
    description = "Traffic allowed to Vault servers"
    tags        = "${var.hashi_tags}"
}

resource aws_security_group_rule "vault_server_ssh_from_world" {
    security_group_id = "${aws_security_group.vault_server_sg.id}"
    type              = "ingress"
    protocol          = "tcp"
    from_port         = 22
    to_port           = 22
    cidr_blocks       = ["0.0.0.0/0"]
}

resource aws_security_group_rule "vault_server_allow_everything_internal" {
    security_group_id = "${aws_security_group.vault_server_sg.id}"
    type              = "ingress"
    protocol          = "all"
    from_port         = 0
    to_port           = 65535
    cidr_blocks       = ["${data.aws_vpc.default.cidr_block}"]
}

resource aws_security_group_rule "vault_server_allow_everything_out" {
    security_group_id = "${aws_security_group.vault_server_sg.id}"
    type              = "egress"
    protocol          = "all"
    from_port         = 0
    to_port           = 65535
    cidr_blocks       = ["0.0.0.0/0"]
}