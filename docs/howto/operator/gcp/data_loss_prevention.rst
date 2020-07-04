 .. Licensed to the Apache Software Foundation (ASF) under one
    or more contributor license agreements.  See the NOTICE file
    distributed with this work for additional information
    regarding copyright ownership.  The ASF licenses this file
    to you under the Apache License, Version 2.0 (the
    "License"); you may not use this file except in compliance
    with the License.  You may obtain a copy of the License at

 ..   http://www.apache.org/licenses/LICENSE-2.0

 .. Unless required by applicable law or agreed to in writing,
    software distributed under the License is distributed on an
    "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
    KIND, either express or implied.  See the License for the
    specific language governing permissions and limitations
    under the License.

Google Cloud Data Loss Prevention Operator
==========================================
`Google Cloud DLP <https://cloud.google.com/dlp>`__, provides tools to classify, mask, tokenize, and transform sensitive
elements to help you better manage the data that you collect, store, or use for business or analytics.

.. contents::
  :depth: 1
  :local:

Prerequisite Tasks
^^^^^^^^^^^^^^^^^^

.. include:: _partials/prerequisite_tasks.rst

Templates
^^^^^^^^^

Templates can be used to create and persist
configuration information to use with the Cloud Data Loss Prevention.
There are two types of templates supported by Cloud DLP:

* `Inspection Template <https://cloud.google.com/dlp/docs/creating-templates-inspect>`__,
* `De-Identification Template <https://cloud.google.com/dlp/docs/creating-templates-deid>`__,

Here we will be using identification template for our example

Creating Template
"""""""""""""""""

To create a inspection template you can use
:class:`~airflow.providers.google.cloud.operators.cloud.dlp.CloudDLPCreateInspectTemplateOperator`.

.. exampleinclude:: ../../../../airflow/providers/google/cloud/example_dags/example_dlp.py
    :language: python
    :dedent: 4
    :start-after: [START howto_operator_dlp_create_inspect_template]
    :end-before: [END howto_operator_dlp_create_inspect_template]

.. _howto/operator:CloudDLPCreateInspectTemplateOperator:

Using Template
""""""""""""""

To find potentially sensitive info using the inspection template we just created, we can use
:class:`~airflow.providers.google.cloud.operators.cloud.dlp.CloudDLPInspectContentOperator`

.. exampleinclude:: ../../../../airflow/providers/google/cloud/example_dags/example_dlp.py
    :language: python
    :dedent: 4
    :start-after: [START howto_operator_dlp_use_inspect_template]
    :end-before: [END howto_operator_dlp_use_inspect_template]

.. _howto/operator:CloudDLPInspectContentOperator:

Deleting Template
"""""""""""""""""

To delete the template you can use
:class:`~airflow.providers.google.cloud.operators.cloud.dlp.CloudDLPDeleteInspectTemplateOperator`.

.. exampleinclude:: ../../../../airflow/providers/google/cloud/example_dags/example_dlp.py
    :language: python
    :dedent: 4
    :start-after: [START howto_operator_dlp_delete_inspect_template]
    :end-before: [END howto_operator_dlp_delete_inspect_template]

.. _howto/operator:CloudDLPDeleteInspectTemplateOperator:

Reference
^^^^^^^^^

For further information, look at:

* `Client Library Documentation <https://googleapis.dev/python/dlp/latest/index.html>`__
* `Product Documentation <https://cloud.google.com/dlp/docs>`__
