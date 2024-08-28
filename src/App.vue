<template>
  <v-app>
    <v-app-bar app color="primary" dark>
      <v-toolbar-title>ETH Task Marketplace</v-toolbar-title>
    </v-app-bar>

    <v-main>
      <TaskMarketplace />
    </v-main>
  </v-app>
</template>

<script setup>
import TaskMarketplace from '@/components/TaskMarketplace.vue';
</script>
