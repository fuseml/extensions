#!/usr/bin/env python

import argparse
import mlflow
import os
import os.path
import re
from typing import AnyStr, Tuple
from mlflow.projects.utils import load_project


def run_mlflow_project(workdir: AnyStr, entrypoint: AnyStr, entrypoint_args: Tuple[AnyStr, AnyStr], experiment: AnyStr,
    artifact_subpath: AnyStr, save_result_to_file: AnyStr) -> None:
    """Run an MLproject entrypoint with arguments read from
    FuseML workflow input parameters and save the result
    artifact URL into the specified file.

    Args:
        workdir (str): path to the directory where the MLproject file resides
        entrypoint (str): MLFlow project entrypoint to execute
        experiment (str): MLFlow experiment name
        artifact_subpath (str): path relative to the the MLFlow project run output
                                artifact storage location to return as result
        result_file (str): location of file where to save the URL of the output artifact
    """
    if not os.path.isfile(os.path.join(workdir, "MLproject")):
        print(f"Could not find MLproject file at location '{os.path.abspath(workdir)}'")
        exit(1)
    project = load_project(workdir)
    if entrypoint not in project._entry_points:
        print(f"Entrypoint '{entrypoint}' not found in MLproject definition file")
        exit(1)
    ep = project.get_entry_point(entrypoint)
    parameters={}

    for arg_name, arg_value in entrypoint_args:
        # Entrypoint arguments that have no correspondent in the MLproject definition
        # file are treated as errors.
        if arg_name not in ep.parameters:
            print(f"Entrypoint '{entrypoint}' does not have an argument with name '{arg_name}'")
            exit(1)
        print(f"Using value for '{arg_name}' entrypoint argument: '{arg_value}'")
        parameters[arg_name] = arg_value

    # This section looks for any entrypoint arguments configured in the MLproject
    # for the indicated entrypoint and attempts to match them to workflow step input
    # parameters.
    #
    # If the user configures a workflow input parameter with the same name as the
    # entrypoint argument, its value will be passed to the MLFlow project run.
    for ep_param in ep.parameters:
        # Entrypoint arguments that are passed explicitly to the command line
        # have priority over those extracted from workflow input parameters
        if ep_param in parameters:
            continue
        v = os.environ.get("FUSEML_"+ep_param.upper())
        if v is not None:
            parameters[ep_param] = v
            print(f"Using workflow input value for '{ep_param}' entrypoint "
                  f"argument: '{v}'")

    print(f"Launching '{entrypoint}' MLFlow entrypoint...")
    try:
        run = mlflow.run(workdir, entrypoint, experiment_name=experiment, parameters=parameters, use_conda=False)
    except Exception as e:
        print(f"MLFlow run for entrypoint '{entrypoint}'' failed")
        raise
    run = mlflow.tracking.MlflowClient().get_run(run.run_id)
    artifact_uri = os.path.join(run.info.artifact_uri, artifact_subpath)
    print(f"Result artifact path: {artifact_uri}")
    if save_result_to_file:
        try:
            with open(save_result_to_file, 'w') as f:
                f.write(artifact_uri)
        except IOError as e:
            print(f"I/O error while saving result to output file "
                  f"'{os.path.abspath(save_result_to_file)}': {e.strerror}")
            exit(1)
        except Exception as e:
            print(f"Unexpected error while saving result to output file "
                  f"'{os.path.abspath(save_result_to_file)}': {str(e)}")



def parse_arguments():

    def entrypoint_arg_type(value: AnyStr) -> Tuple[AnyStr, AnyStr]:
        """Parse an entrypoint argument in the form <name>=<value>.

        Args:
            value (AnyStr): string representation, as read from command line

        Raises:
            argparse.ArgumentTypeError: if argument isn't formatted correctly

        Returns:
            Tuple[AnyStr, AnyStr]: returns the parsed argument name and value
        """
        regex=re.compile(r"^(\w+)\=(.*)$")
        match=regex.match(value)
        if not match:
            raise argparse.ArgumentTypeError(f"Invalid format for --entrypoint_args value: {value}")
        return match.group(1), match.group(2)

    parser = argparse.ArgumentParser(
        description='FuseML workflow step wrapper for MLFlow projects. '
                    'Maps workflow input parameters to the corresponding entrypoint arguments '
                    'configured in the MLproject.')
    parser.add_argument('--workdir', required=False, default='.',
                        help='MLFlow work directory where MLproject is located')
    parser.add_argument('--entrypoint', required=False, default='main',
                        help='MLproject entrypoint to execute')
    parser.add_argument('--entrypoint_args', required=False, nargs='*', type=entrypoint_arg_type,
                        help='List of additional MLproject run entrypoint arguments in the form <name>=<value>')
    parser.add_argument('--experiment', required=False, default='',
                        help='MLFlow experiment name to use for project run')
    parser.add_argument('--artifact_subpath', required=False, default='model',
                        help='Specify a file or folder under the MLFlow run artifacts location '
                        'to return as workflow result')
    parser.add_argument('--save_result_to_file', required=False, default=None,
                        help='Specify a file where to save the URL of the resulted MLFlow artifact. '
                        'If not set, the resulted MLFlow artifact URL will only be printed.')
    args = vars(parser.parse_args())

    return args


def main():
    args = parse_arguments()
    run_mlflow_project(**args)


if __name__ == "__main__":
    main()
