# Chrony

## Introduction

This is a helm chart for chrony, it is intended to be used in a cluster configuration. On a cluster of Raspberry Pi 5's, with hardware Realtime Clocks on each node. This chart will deploy chrony to all the nodes as a daemonset, it is intended to be used with a NTP server.

## Dockerfile

This dockerfile is used to build the image for the chrony container, I have chosen to setup a build process from source. This is because I want to always capture the latest version of chrony, and I don't want to have to build it every time I make a change to the chart.

## 