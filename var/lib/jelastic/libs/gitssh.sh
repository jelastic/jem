#!/bin/bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o "NumberOfPasswordPrompts 0" -i $AUTHORIZATION_KEY  $@
